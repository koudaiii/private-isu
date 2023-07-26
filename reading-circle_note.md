# 輪読会 演習メモ

書籍「達人が教えるWebパフォーマンスチューニング～ISUCONから学ぶ高速化の実践」の3章で紹介されるprivate-isuを実際に動かしてみるための手順を簡単にまとめたドキュメントです。

Dev containerでprivate-isuのDockerによる起動ができるように構成しているので、GitHub CodespacesやDev containerとして起動し利用してください。

## 3章

### 3-1 本書で扱うWebサービスprivate-isu

書籍で解説されているMySQLデータベースの初期データのダウンロードと解凍はすでに済んでいます。

Dockerを起動するには下記コマンドを実行します。

```bash
cd webapp
docker compose up
```

以下のように`ready for connections`と表示されれば、起動ができました。

```
webapp-mysql-1      | 2023-06-06 09:18:03+00:00 [Note] [Entrypoint]: /usr/local/bin/docker-entrypoint.sh: running /docker-entrypoint-initdb.d/dump.sql
...
webapp-mysql-1      | 2023-06-06T09:26:26.322821Z 0 [System] [MY-011323] [Server] X Plugin ready for connections. Bind-address: '::' port: 33060, socket: /var/run/mysqld/mysqlx.sock
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

負荷試験に利用する`alp`はすでにインストールされています。

nginxのアクセスログは、Dockerの`nginx`サービスの`/var/log/nginx`に出力されるので、そのディレクトリを[`webapp/logs/nginx`](./webapp/logs/nginx)にマウントし、手元から参照できるようにしています。そのため、`alp`コマンドは下記のように実行できます。

```bash
cat webapp/logs/nginx/access.log | alp json
```

### 3-3 ベンチマーカーによる負荷試験の実行

この節で利用するベンチマーカー`ab`は、既にインストールされています。

下記を実行して負荷をかけてみます。

```bash
ab -c 1 -n 10 http://localhost/
```

アクセスログの末尾10行を`alp`に渡して結果を比較してみます。

```bash
tail -n 10 webapp/logs/nginx/access.log | alp json -o count,method,uri,min,avg,max
```

アクセスログのローテーションは、下記にようにnginxのDockerインスタンスにログインしてからファイルをリネームします。

```bash
docker exec -it webapp-nginx-1 /bin/bash
mv /var/log/nginx/access.log /var/log/nginx/access.log.old
```

nginxがまだリネーム後のファイルを掴んでいるので、nginxをリロードするか、プロセスにシグナルを送ります。

```bash
# リロードする場合
service nginx reload

# nginxにリオープンのシグナルを送る場合
/usr/sbin/nginx -s reopen
```

### 3-4 パフォーマンスチューニング 最初の一歩

1並列で30秒間リクエストを送って負荷を探ります。

ここからは性能指標として、Requests per secondを用います。以下の理由です。

- 負荷試験のスコアとして、パフォーマンスを改善すると向上する数値の方が感覚的にわかりやすい
- 前節で採用したレイテンシ（レスポンスタイム）を指標とする場合、その値を削減していっても、利用者の体感に変化がなくなる下限が存在しわかりにくい

負荷をかけている途中、マシンの負荷を観察できるように、`top`コマンドを実行しておきます。CPUコアごとに表示したい場合は`1`を入力して切り替えておきます。

```bash
top
```

`top`コマンドでもDockerインスタンス内のプロセスを透過して確認することができます。

また、`docker stats`コマンドを利用すると、各Dockerインスタンスごとの負荷を確認することができます。

```bash
docker stats
```

下記コマンドで負荷をかけます。

```bash
ab -c 1 -t 30 http://localhost/
```

上記の確認で、`mysqld`がCPUを占有していることがわかったので、スロークエリを出力して処理の内訳を核にしてみます。

`my.cnf`に下記を記述することでスロークエリログを出力します。

```
[mysqld]
slow_query_log = 1
slow_query_log_file = /var/log/mysql/mysql-slow.log
long_query_time = 0
```

Dockerの場合は、`webapp/etc/mysql/conf.d/my.cnf`に記述し、以下のように`webapp/docker-compose.yml`でログの出力先をマウントした上で、MySQLを再起動します。（一度 `docker compose down`してから`docker compose up`がわかりやすい）

`webapp/docker-compose.yml`

```diff
    mysql:
      ...
      volumes:
        - ...
+       - ./logs/mysql:/var/log/mysql
```

MySQLの再起動ができたら、

スロークエリの分析には`mysqldumpslow`コマンドが便利です。コマンドが見つからない場合は、`mysql-server`をインストールしてください。

```bash
mysqldumpslow webapp/logs/mysql/mysql-slow.log
```

スロークエリログのローテーションは、下記にようにmysqlのDockerインスタンスにログインしてからファイルをリネームします。

```bash
docker exec -it webapp-mysql-1 /bin/bash
mv /var/log/mysql/mysql-slow.log /var/log/mysql/mysql-slow.log.old
```

MySQLでクエリを実行する場合は、以下を実行します。

```bash
docker exec -it webapp-mysql-1 mysql -u root -p
```

```mysql
use isuconp;
SHOW CREATE TABLE comments;
EXPLAIN SELECT * FROM `comments` WHERE `post_id` = 9995 ORDER BY `created_at` DESC LIMIT 3;
ALTER TABLE comments ADD INDEX post_id_idx(post_id);
```
