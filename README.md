# AWSPriceListAPIをPowreShellで叩いてみる

AWSPriceListがリージョン毎取得出来るようになったようなのでPowreshellでAPIを叩いて。
リージョン毎のPriceListを取得してみたり表示してみたり。

scriptFile|説明
----|----
Get-AWSPriceList.ps1 | ファイルのダウンロード
View-AWSPriceList.ps1 | jsonファイルの表示

## Get-AWSPriceList.ps1

スクリプトを実行すると

![](image/step001.png)

AWSPriceListでサポートされているサービスの一覧が出力される。

ついで、選択条件入力画面が表示されるので欲しいファイルの条件を入力する。

![](image/step002.png)

デフォルト値が設定されるので、特に入力が無い時は。

- AmazonEC2
- ap-northeast-1 東京
- json

の条件でデータ抽出を行う。

ファイルのダウンロード場所はスクリプトが格納されている同階層のdownloadFileというフォルダに行う。
フォルダが無ければ該当フォルダを作成して保存する。

ファイル名はサービス名.リージョン名.刊行日.拡張子。

## View-AWSPriceList.ps1

※AmazonEC2とAmazonS3のjsonファイルの情報を表示出来ることを目標に。
とりえあず全項目表示してみたが、他サービスのjsonファイルでも動くかどうかは不明。

スクリプトを実行すると

![](image/step003.png)

jsonファイルのパスを入れろとでるので入力してenter。

![](image/step004.png)

しばらく待つと

![](image/step005.png)

grid-viewで情報が参照できる。

AmazonEC2の場合。情報の大半がリザーブドなので必要ない場合はリザーブドを抜く用にしたほうがいいかも？　今のところ無条件でオンデマンド・リザーブド全表示している。
