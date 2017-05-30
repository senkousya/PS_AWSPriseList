function Get-AWSPriceList{
    #AmazonPriceListAPIのベースUri
    $baseUri="https://pricing.us-east-1.amazonaws.com"

    #全リージョンのサービス一覧を取得
    [array]$AWSServiceList = ((Invoke-RestMethod "$baseUri/offers/v1.0/aws/index.json").offers.psobject.Properties.name)

    #サービス一覧を表示
    write-host "サービス一覧"
    $AWSServiceList | format-List

    write-host "====================================="
    write-host "選択条件入力"
    write-host "====================================="
    #選択条件入力
    $serviceName = read-host -Prompt "サービス[default:AmazonEC2]"
    $regionName　= read-host -Prompt "リージョン[default:ap-northeast-1]"
    $fileType = read-host -Prompt "形式json/csv[default:json]"

    #未入力ならデフォルト値入力
    if(-not ($serviceName)){$serviceName = "AmazonEC2"}
    if(-not ($regionName)){$regionName = "ap-northeast-1"}
    if(-not ($fileType)){$fileType = "json"}

    #対象が存在するサービスかどうか検索
    if($AWSServiceList -contains $serviceName){

        #リージョン別のインデックデータAPI URL
        $indexEndpoint = ($baseUri +"/offers/v1.0/aws/" + $serviceName +"/current/region_index.json")
        #リージョン別のサービスインデックスデータ取得
        $regionIndex = Invoke-RestMethod -uri $indexEndpoint

        #該当サービスのリージョン一覧を取得
        [array]$AWSRegionList = $regionIndex.regions.psobject.Properties.name

        #該当サービスの指定リージョンでPriceListが存在するかチェック
        if( $AWSRegionList -contains $regionName){
            #priceList API用のURL作成
            #PriceListAPIでサポートしている形式はjson or csv
            #memo
            #json形式位はproducts（製品情報）とterms（価格情報）が分離されていてskuで紐付けてやるとPriceListができる
            #csv形式だとproductsとtermsが合わさった形で提供されている
            #拡張子を変えてアクセスするとそれぞれの形式でダウンロード出来る

            #対象のファイルタイプに調整
            $currentVersionUrl = ($regionIndex.regions.($regionName).currentVersionUrl)
            #拡張子を分離
            if($currentVersionUrl　-match "(^.*\.)([^.]+)"){
                $adjustCurrentVersionUri = ($Matches[1] + $fileType)
                $offerEndpoint = ($baseUri + $adjustCurrentVersionUri)
                write-host $offerEndpoint
            }else{
                exit 9
            }

            #PriceList取得
            try{
                #ダウンロードディレクトリ
                $downloadDir = "$PSScriptRoot/downloadFile/"
                #ダウンロードファイル名
                $downloadFileName = $serviceName + "." + $regionName + "." +($regionIndex.publicationDate) + "." + $fileType
                #禁止文字を除外
                $downloadFileName = $downloadFileName -replace "[/:*?]"
                #フルパス作成
                $downloadFullPath = "$downloadDir$downloadFileName"
                #ダウンロードディレクトリの存在チェック。なければディレクトリ作成
                if( -not (test-path $downloadDir)){ New-Item $downloadDir -itemType Directory }
                #offerファイル取得
                Invoke-RestMethod -uri $offerEndpoint -OutFile $downloadFullPath -method GET
                #処理成功
                write-host "[Success]:    $downloadFullPath"
            }catch{
                #処理失敗
                write-host "[Faild]"
                exit 8
            }
        }else{
            write-host "$serviceName    指定リージョンのPriceListが存在しません"
        }
    }else{
        write-host "サービスが存在しません"
    }
}

Get-AWSPriceList