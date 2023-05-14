# 輪読会 演習メモ

書籍「達人が教えるWebパフォーマンスチューニング～ISUCONから学ぶ高速化の実践」の3章で紹介されるprivate-isuを実際に動かしてみるための手順を簡単にまとめたドキュメントです。

Dev containerでprivate-isuのDockerによる起動ができるように構成しているので、GitHub CodespacesやDev containerとして起動し利用してください。

## 3章

### 3-1 本書で扱うWebサービスprivate-isu

書籍で解説されているMySQLデータベースの初期データのダウンロードと解凍はすでに済んでいます。

Dockerを起動するには下記コマンドを実行します。

```bash
docker compose up
```

### 3-2 負荷試験の準備

#### リスト4 nginxでJSON形式のアクセスログを出力する設定例

書籍の解説に沿い、nginxのアクセスログの出力をJSON形式に変更します。既に設定済みですが、具体的には、Dockerの`nginx`サービスにマウントで渡している[`default.conf`](./webapp/etc/nginx/conf.d/default.conf)に、下記の記述を追記しています。`log_format`は`server{`の前に、`access_log`は`server {`の中に設定しています。

```
log_format json escape=json '{"time":"$time_iso8601",'
  '"host":"$remote_addr",'
  '"port":$remote_port,'
  '"method":"$request_method",'
  '"uri":"$request_uri",'
  '"status":"$status",'
  '"body_bytes":$body_bytes_sent,'
  '"referer":"$http_referer",'
  '"ua":"$http_user_agent",'
  '"request_time":"$request_time",'
  '"response_time":"$upstream_response_time"}';
```

```
access_log /var/log/nginx/access.log json;
```

負荷試験に利用する`alp`はすでにインストールしています。

nginxのアクセスログは、Dockerの`nginx`サービスの`/var/log/nginx`に出力されるので、そのディレクトリを[`webapp/logs/nginx`](./webapp/logs/nginx)にマウントし、手元から参照できるようにしています。そのため、`alp`コマンドは下記のように実行できます。

```bash
cat webapp/logs/nginx/access.log | alp json
```
