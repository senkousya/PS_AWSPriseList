BEGIN {
    function Save-OfferFile {
        <#
.SYNOPSIS
AWSPriceLisrtでOfferFileのダウンロード
.DESCRIPTION
指定されたcurrentVersionUrlのファイルをダウンロードする
.PARAMETER OfferCode
ファイル名に利用
.PARAMETER BaseUri
AWSPriceListのBaseUri
.PARAMETER CurrentVersionUrl
取得するファイルのCurrentVersionUrl
.PARAMETER FileType
取得するファイルのファイルタイプ
.PARAMETER RegionCode
ファイル名に利用
.PARAMETER PublicationDate
ファイル名に利用
.PARAMETER DownloadDir
ダウンロードディレクトリ
#>

        [CmdletBinding()]
        # Parameter help description
        PARAM(
            [Parameter(Mandatory = $True)][string]$OfferCode,
            [Parameter(Mandatory = $True)][string]$BaseUri,
            [Parameter(Mandatory = $True)][string]$CurrentVersionUrl,
            [Parameter(Mandatory = $True)][string]$FileType,
            [Parameter(Mandatory = $True)][string]$RegionCode,
            [Parameter(Mandatory = $True)][string]$PublicationDate,
            [Parameter(Mandatory = $false)][string]$DownloadDir = ( $pwd.path )
        )
        PROCESS {
            #currentVersionUrlからAPI実行用のエンドポイント作成
            #memo
            #PriceListAPIでサポートしている形式はjson or csv
            #json形式位はproducts（製品情報）とterms（価格情報）が分離されていてskuで紐付けてやるとPriceListができる
            #csv形式だとproductsとtermsが合わさった形で提供されている
            #拡張子を変えてアクセスするとそれぞれの形式でダウンロード出来る

            #拡張子を分離
            if ($currentVersionUrl　-match "(^.*\.)([^.]+)") {
                #指定した拡張子を付与
                $adjustCurrentVersionUri = ($Matches[1] + $FileType)
                #endpoint設定
                $offerEndpoint = ($BaseUri + $adjustCurrentVersionUri)
            }
            else {
                exit 9
            }

            try {
                #ダウンロードファイル名
                $downloadFileName = $OfferCode + "." + $RegionCode + "." + $PublicationDate + "." + $FileType
                #禁止文字を除外
                $downloadFileName = $downloadFileName -replace "[/:*?]"
                #フルパス作成
                $downloadFullPath = Join-Path -path $downloadDir -ChildPath $downloadFileName
                #ダウンロードディレクトリの存在チェック。なければディレクトリ作成
                if ( -not (test-path $downloadDir)) { New-Item $downloadDir -itemType Directory }
            
                #VerboseにENDPOINTを書き込み
                Write-Verbose -Message ("[ENDPOINT:]" + $offerEndpoint)

                #offerファイル取得
                Invoke-RestMethod -uri $offerEndpoint -OutFile $downloadFullPath -method GET > $NULL
                #Verboseに書き込み(成功)
                Write-Verbose -Message "[Success]:    $downloadFullPath"
            }
            catch {
                #Verboseに書き込み(失敗)
                Write-Verbose -Message "[Faild]"
                exit 8
            }
        }

    }

    function Get-AWSPriceList {

        [CmdletBinding()]
        PARAM()
    
        PROCESS {
            #AmazonPriceListAPIのベースUri
            $baseUri = "https://pricing.us-east-1.amazonaws.com"

            #AWSPriceListのIndexを取得
            $AWSIndexTable = ( Invoke-RestMethod -Uri "$baseUri/offers/v1.0/aws/index.json" -Method Get )

            #サービス一覧を表示
            write-host "サービス一覧"
            ($AWSIndexTable.offers.psobject.Properties) | Format-Wide -Property name -AutoSize

            write-host "====================================="
            write-host "選択条件入力"
            write-host "====================================="
            #選択条件入力
            $offerCode = read-host -Prompt "サービス[default:AmazonEC2]"
            $regionCode　= read-host -Prompt "リージョン[default:ap-northeast-1]"
            $fileType = read-host -Prompt "形式json/csv[default:json]"

            #未入力ならデフォルト値入力
            if (-not ($offerCode)) {$offerCode = "AmazonEC2"}
            if (-not ($regionCode)) {$regionCode = "ap-northeast-1"}
            if (-not ($fileType)) {$fileType = "json"}

            #ダウンロードディレクトリ設定
            $downloadDir = (Join-Path -path $PSScriptRoot -ChildPath "downloadFile")

            #指定されたサービスでレコード抽出
            $targetAWSIndexTable = ( $AWSIndexTable.offers.psobject.properties.value | Where-Object offerCode -like $OfferCode )

            if ([string]::IsNullOrEmpty($targetAWSIndexTable)) {
                #対象サービスがない場合
                Write-Verbose -Message "対象となるサービスがありませんでした"
            }
            else {
    
                foreach ($targetAWSIndex in $targetAWSIndexTable) {

                    #オファーファイルの取得
                    #currentRegionIndexUrlが存在する場合はreagionIndexを読んでリージョン分割されたオファーファイルを取得
                    #currentRegionIndexUrlがNULL（リージョン分割されたオファーファイルが存在しない）なサービスはリージョン分割されていないオファーファイルを取得
                    #リージョン別対応した2017/04/20以降価格改定がないサービスはリージョン別のオファーファイルがない？
                    IF ([String]::IsNullOrEmpty($targetAWSIndex.currentRegionIndexUrl)) {

                        Write-Verbose -Message ( $targetAWSIndex.offerCode + "[リージョン別オファーファイルなし]" )
                        Write-Verbose -Message "リージョン分割されていないオファーファイルを取得します"
                        #リージョン別のオファーファイルが存在しない場合
                        #indexファイルよりcurrentVersion取得
                        $indexEndpoint = $baseUri + $targetAWSIndex.versionIndexUrl
                        $Index = Invoke-RestMethod -uri $indexEndpoint

                        #Save-OfferFileの引数設定

                        $downloadParameters = @{}
                        $downloadParameters.add( "OfferCode" , $targetAWSIndex.offerCode )
                        $downloadParameters.add( "BaseUri" , $baseUri )
                        $downloadParameters.add( "CurrentVersionUrl" , $targetAWSIndex.currentVersionUrl )
                        $downloadParameters.add( "FileType" , $fileType )
                        $downloadParameters.add( "RegionCode" , "AllRegion" )
                        $downloadParameters.add( "PublicationDate" , $index.publicationDate )
                        $downloadParameters.add( "DownloadDir" , $downloadDir )

                        Save-OfferFile @downloadParameters

                        $downloadParameters.clear()

                    }
                    else {
                        #リージョン別のオファーファイルが存在する場合
                        #リージョン別のインデックデータのURI設定
                        $regionIndexEndpoint = $baseUri + $targetAWSIndex.currentRegionIndexUrl
                        #リージョン別のAWSPriceListIndexを取得
                        $regionIndex = Invoke-RestMethod -uri $regionIndexEndpoint

                        #指定されたリージョンでレコード抽出
                        $targetRegionIndexTable = ( $regionIndex.regions.psobject.Properties.value | Where-Object regionCode -like $regionCode )
                
                        #該当サービスの指定リージョンでPriceListが存在するかチェック
                        if ([string]::IsNullOrEmpty($targetRegionIndexTable)) {
                            #Verboseに書き込み(対象リージョンなし)
                            Write-Verbose -Message ( $targetAWSIndex.offerCode + "[指定された条件に合致するリージョンのPriceListが存在しません]" )
                        }
                        else {
                            #Verboseに書き込み(対象リージョンあり)
                            Write-Verbose -Message ( $targetAWSIndex.offerCode + "[リージョン分割されたオファーファイルをダウンロード]" )
                    
                            foreach ( $targetRegionIndex in $targetRegionIndexTable ) {
                    
                                #Save-OfferFileの引数設定
                                $downloadParameters = @{}
                                $downloadParameters.add( "OfferCode" , $targetAWSIndex.offerCode )
                                $downloadParameters.add( "BaseUri" , $baseUri )
                                $downloadParameters.add( "CurrentVersionUrl" , $targetRegionIndex.currentVersionUrl )
                                $downloadParameters.add( "FileType" , $fileType )
                                $downloadParameters.add( "RegionCode" , $targetRegionIndex.regionCode )
                                $downloadParameters.add( "PublicationDate" , $regionIndex.publicationDate )
                                $downloadParameters.add( "DownloadDir" , $downloadDir )

                                Save-OfferFile @downloadParameters
                                $downloadParameters.clear()
                            }
                        }
                    }
                }
            }
        }
    }
}

PROCESS {
    Get-AWSPriceList -verbose
}
