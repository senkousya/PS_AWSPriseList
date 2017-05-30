[cmdletbinding()]
param(
[Parameter(Position=0,Mandatory=$True,HelpMessage="Enter a json file path")][string]$jsonFilePath
)

begin{
#ファイルの存在チェック
if( -not ( test-path $jsonFilePath )){ write-host 対象が存在しません ;exit 9} 
}

process{
    
    function convertToDisplayFormat{
        [cmdletbinding()]
        param(
            [Parameter(Mandatory=$True,HelpMessage="製品情報")][System.Object]$products,
            [Parameter(Mandatory=$True,HelpMessage="価格情報")][System.Object]$terms,
            [Parameter(Mandatory=$True,HelpMessage="価格タイプ(Ondemande.reserved)")][String]$termType
	    )

            #プロパティ(sku)で格納されている情報をとりえず変数に格納
            $skuOffer = $terms.psobject.Properties.name | %{($terms.($_)).psobject.Properties.value}
           
            #productに存在する全プロパティを取得
            [array]$productComp = @()
            (($products.psobject.Properties.value).attributes) | %{ $productComp += $_.psobject.properties.name ; $productComp = $productComp | select -unique }

            #termsに存在する全プロパティを取得
            [array]$termComp = @()
            $termComp += ($skuOffer | %{($_.priceDimensions.psobject.Properties.value)} | %{($_.psobject.properties.name)}) | select -Unique

            #調整用のtemp構造定義
            $tempHashTable = [ordered]@{}

            #価格情報をループして表示用のデータ作成
            foreach($skuOfferLine in $skuOffer){
                #skuで製品情報を取得
                $product = ($products.($skuOfferLine.sku))

                $rateCodes = ($skuOfferLine.priceDimensions.psobject.Properties.value)

                foreach($ratecode in $rateCodes){

                    #一時変数のクリア
                    $tempHashTable.clear()

                    #termType
                    $tempHashTable += @{ "termType" = $termType }
                    #製品情報書込み
                    $productComp | %{ $tempHashTable += @{ $_ = $product.attributes.($_) } }
                    #価格情報書込み
                    ($termComp) | %{ $tempHashTable += @{ $_ = $rateCode.($_) } }
                    #hashtableをPScustomObjectにキャストしてArray構造に渡す
                    [Array]$returnArray += [PSCustomObject]$tempHashTable
                }

            }
        #戻り値書込み
        write-output $returnArray

    }

    #ファイルパス取得
    $contents = Get-Content $jsonFilePath | convertFrom-json

    #サービス名表示
    write-host $contents.offerCode
    #バージョン表示
    write-host $contents.version

    [array]$outputArray = @{}

    #製品情報と価格情報をディスプレイ表示変換にかけて出力用データの作成
    $outputArray += ($contents.terms.psobject.Properties.name) | %{(convertToDisplayFormat -products ($contents.products) -terms $contents.terms.($_) -termType $_ )}

    #データ表示
    $outputArray | Out-GridView

    $outputArray.clear()    
    
}
