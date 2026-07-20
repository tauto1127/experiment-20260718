# Cartographer cloud robotics experiment

Cartographer/mROS 2 WASM実験の評価用リポジトリです。

実装本体は [`mros2-wasm`](mros2-wasm/) サブモジュールとして固定しています。
依存関係のスナップショットは [`deps.lock`](deps.lock) に記録します。

実験用のビルド・測定スクリプトや結果データは、実験条件と対応付けて保存します。

## 実験概要

Raspberry Pi 上で動作するロボットシステムの一部を WASM 化し、クラウドロボティクス構成として分離することの有用性を評価します。対象アプリケーションには Cartographer の地図生成処理を使用し、`occupancy_grid_node` を WASM ノードとして実行する構成を比較します。

主な比較ケースは次の2つです。

1. すべてのノードを Raspberry Pi 上で実行する構成
2. Raspberry Pi 上で mROS 2 のノード群を実行し、`occupancy_grid_node` だけを WASM として実行する構成

両ケースで同じセンサ入力、同じ地図生成条件、同じネットワーク条件を使用し、処理の配置だけを変えます。比較対象を明確にするため、各ケースで「どのノードをどのホストで実行したか」を一覧にします。

## 実験条件として明記する項目

### 実行環境

- Raspberry Pi の型番、メモリ容量、OS、カーネル、CPU governor、電源と冷却条件
- 実行ホストの型番、OS、CPU、メモリ、ネットワーク接続（有線／無線）
- Cartographer、ROS 2、mROS 2、WAMR、WASI SDK、コンパイラ、Rust/Cargo のバージョン
- 実験リポジトリ、`mros2-wasm`、および再帰的サブモジュールのコミットID
- 実験開始時刻、実験時間、ウォームアップ時間、繰り返し回数

### ネットワーク

この実験では仮想ネットワークカードを使用せず、物理インターフェースを使用します。現在の基準構成は次のとおりです。

- Raspberry Pi のインターフェース: `eth0`
- Raspberry Pi のアドレス: `192.168.100.3/24`
- ネットマスク: `255.255.255.0`
- `mros2-wasm` の `IP_ADDRESS` と `NETIF_IPADDR`: `192.168.100.3`

実験ごとに、全ホストのIPアドレス、インターフェース名、経路、ROS_DOMAIN_ID、RMW/DDS設定、マルチキャスト設定、ファイアウォールの状態を記録します。アドレスを変更した場合は、ソースの固定IP設定と実行ログの両方を更新します。

### 入力と処理条件

- 使用した rosbag のファイル名、取得条件、サイズ、ハッシュ値
- センサトピック名、メッセージ型、入力頻度、再生速度、時刻の扱い
- Cartographer の設定ファイル、解像度、地図範囲、サブマップ設定
- ノードの起動順、起動完了の判定、bag再生開始時刻、終了条件
- 各比較ケースでのノード配置と、ネイティブ／WASMの別

入力データ、設定、bagの再生速度、実験時間は両ケースで揃えます。ビルド時間やプロセス起動時間を測定対象に含める場合は、実行時レイテンシと分けて記録します。

### WASMのビルドと実行

WAMR は classic interpreter を使用します。スレッド関連の指定は次の2つです。

```text
-DWAMR_BUILD_LIB_WASI_THREADS=1
-DWAMR_BUILD_THREAD_MGR=1
```

現在の基準ビルドでは、これらに加えて interpreter、reference types、debug の設定を明示します。

```text
-DWAMR_BUILD_DEBUG_INTERP=0
-DWAMR_BUILD_FAST_INTERP=0
-DWAMR_BUILD_INTERP=1
-DWAMR_BUILD_REF_TYPES=1
```

`mros2-wasm` は、依存サブモジュールを所定のコミットに揃えた後、対象ノードを clean にビルドします。

```bash
./build.bash all occupancy_grid_node
```

`up` は既存の生成物を利用する増分ビルドなので、比較実験の開始時には生成物を再利用せず、使用したビルドディレクトリ、WASMファイルのSHA-256、`iwasm` のSHA-256を記録します。実行時には WAMR のオプション（最大スレッド数、WASMヒープサイズ、アドレスプール、公開ディレクトリ）も記録します。

### 測定方法

各測定値について、対象、単位、サンプリング周期、測定器またはコマンド、集計方法を明記します。

- 電力: Raspberry Pi単体かシステム全体か、瞬時電力か積算エネルギーか
- CPU: ホスト全体かプロセス単位か、平均・最大・各コアの値か
- メモリ: RSS、WAMRヒープ、システム空きメモリのどれか
- レイテンシ: 入力メッセージのタイムスタンプから `occupancy_grid` publish までか、通信区間だけか
- 通信: 送受信バイト数、メッセージ数、欠落、再送、接続確立時間
- 地図: 更新周期、更新回数、地図サイズ、最終地図の一致または差分

レイテンシの計測では、開始点・終了点・時計の種類・タイムスタンプの発生箇所を固定します。ウォームアップ区間は集計から除外するかどうかを先に決め、平均値だけでなく、中央値、最大値、p95/p99などの分布も保存します。

## 測定項目

構成ごとに、可能な範囲で次の項目を測定します。

- Raspberry Pi および WASM 実行環境の消費電力
- CPU 使用率、メモリ使用量、必要に応じて温度や周波数
- センサ入力から地図更新・`occupancy_grid` publish までのレイテンシ
- ノード間通信の遅延、スループット、メッセージ欠落の有無
- 地図生成の処理時間と実験全体の再現性

測定結果は、単純な処理速度だけでなく、通信オーバーヘッド・消費電力・計算資源とのトレードオフとして比較します。これにより、どの処理を Raspberry Pi から分離すると有効か、また WASM 化による遅延が実用上許容できるかを評価します。

`scripts/run_wasm_offline_measurement.sh` は 1 秒間隔でプロセス別の
`process_metrics.csv` と、実行機全体の `system_metrics.csv` を出力します。
後者には、全CPUコアを合計した CPU 使用率と、`MemAvailable` を差し引いた
メモリ使用量を記録します。WASMをホストへ配置する比較ケースでは、同じ
`collect_system_metrics.sh` を Raspberry Pi 側とホスト側の両方で実行し、
各マシンの値を別ファイルとして保存します。

## 測定手順

### 共通条件

- 入力には同一の `turtlebot3_simulation_bag` を使用する。
- `use_sim_time:=true` と `ros2 bag play --clock` を使用する。
- mROS 2 は固定 IP アドレスを使う。実験前に Raspberry Pi は
  `192.168.100.3`、ホストは `192.168.100.11` であることを確認する。
- 仮想ネットワークインタフェースは使わず、両機の物理 NIC を使用する。
- 各ケースを少なくとも 3 回実行し、平均だけでなく中央値・最小値・最大値を
  保存する。電力計の表示値は試行ごとに手で記録する。

### ケース A: 全ノードを Raspberry Pi で実行

Raspberry Pi 上で次を実行する。

```bash
./scripts/run_wasm_offline_measurement.sh results/run-$(date +%Y%m%dT%H%M%S)
```

このスクリプトは以下の順に起動する。

1. `iwasm` で `occupancy_grid_node.wasm` を起動する。
2. `cartographer_no_occupancy.launch.py` を起動する。
3. rosbag を `--clock` 付きで再生する。

起動順は重要である。mROS 2 ノードを先に起動しないと、後から起動する
Cartographer が必要な通信を発見できない場合がある。

### ケース B: occupancy grid ノードだけをホストで実行

ホストで `occupancy_grid_node.wasm` を `iwasm` により起動し、Pi では
Cartographer と rosbag のみを起動する。ホスト側の WASM ノードを先に
`ready to pub/sub message` まで起動してから、Pi 側で Cartographer、rosbag の
順に起動する。

ホストで次を実行すると、ホスト側WASMの起動、両機のCPU/RAM計測、Piでの
Cartographer/rosbag実行、Pi結果の回収、ホスト側レイテンシ集計を一括で行う。
`HOST_MROS2_WASM_DIR` は、ホストIP向けにビルド済みの `mros2-wasm` を指定する。

```bash
HOST_MROS2_WASM_DIR=/path/to/built/mros2-wasm \
  ./scripts/run_cloud_wasm_measurement.sh results/cloud-$(date +%Y%m%dT%H%M%S)
```

SSH経由でPiの標準出力がホスト端末へ転送される。Cartographerプロセスを検出した
時点で `POWER_MEASUREMENT_START` が表示されるため、その表示をPi電力計測の開始点と
する。SCPによる結果回収の直前に `POWER_MEASUREMENT_END` が表示されるため、その表示を
Pi電力計測の終了点とする。結果は `RESULT_DIR/pi/` と `RESULT_DIR/host/` に分けて保存される。

このケースでは、以下を同時に実行してマシン別の値を保存する。

```bash
# Raspberry Pi
scripts/collect_system_metrics.sh pi_system_metrics.csv

# ホスト
scripts/collect_system_metrics.sh host_system_metrics.csv
```

プロセス別の値も必要な場合は、各マシンで対象 PID を指定する。

```bash
scripts/collect_process_metrics.sh process_metrics.csv \
  'iwasm:PID' 'cartographer:PID' 'rosbag:PID'
```

ケース B の Pi では `iwasm` を指定しない。ホストでは `iwasm` だけを指定する。

## 出力と集計

### CPU・メモリ

`system_metrics.csv` は 1 秒間隔の実行機全体の値である。

- `cpu_percent`: 全CPUコアの稼働時間を合計して 0--100% に正規化した使用率。
  100% は全コアが使用中であることを表す。
- `mem_used_kb`: `MemTotal - MemAvailable`。再利用可能なページキャッシュを
  必要以上に使用量として数えない。
- `mem_used_percent`: 上記メモリ使用量を `MemTotal` で割った割合。
- `swap_total_kb`, `swap_free_kb`: スワップの使用状況。

初期化中の値を除外するため、比較時は WASM ノード（ケース A）または
Cartographer/rosbag（ケース B）が稼働している時刻範囲だけを集計する。

`process_metrics.csv` はプロセス単位の値である。`cpu_percent` は 1 CPU コアを
100% とするため、スレッドを複数使うプロセスでは 100% を超え得る。
`rss_kb` は実メモリ上に常駐している量、`vmhwm_kb` はその最大値である。

### レイテンシ

WASM ノードは `/tmp/occupancy_grid_node_metrics.csv` に次のイベントを
ミリ秒単位で記録する。

| イベント | 意味 |
| --- | --- |
| `submap_list_received` | `/submap_list` を受信した時刻 |
| `submap_query_request_sent` | `/submap_query` 要求を送信した時刻 |
| `submap_query_complete` | 必要な `/submap_query` 応答がそろった時刻 |
| `occupancy_grid_generated` | occupancy grid の生成完了時刻 |
| `map_file_write_complete` | 地図ファイルの書込みと `fsync` 完了時刻 |

次のコマンドで、`/submap_list` 受信を基準とした遅延 CSV を作る。

```bash
scripts/summarize_latency.sh occupancy_grid_node_metrics.csv > latency_summary.csv
```

`latency_summary.csv` の各列は以下である。

- `first_query_complete_ms` / `last_query_complete_ms`:
  `/submap_list` 受信から `/submap_query` 完了まで。
- `occupancy_grid_generated_ms`: `/submap_list` 受信から grid 生成完了まで。
- `map_file_write_complete_ms`: `/submap_list` 受信から地図ファイルの安全な書込み
  完了まで。

DDS の再送や周期 publish により同じ内容の `/submap_list` を複数回受信することが
ある。そのため `submap_list_seq` は「受信回数」のローカル連番であり、地図更新の
一意な識別子ではない。集計では、同一試行内で有効な query 完了とその後の最初の
grid 生成・ファイル書込みを対応付け、重複受信による行数の増加を明記する。

### 電力

Raspberry Pi の給電経路に電力計を置き、rosbag 再生開始直前から終了直後までの
消費電力または積算電力量を記録する。アイドル時の値も別に測り、実験中の値と
区別する。ホストの電力を評価対象に含める場合も、同じ時間窓で別の計測器により
記録する。

## 結果ディレクトリの最低構成

各試行の結果ディレクトリには少なくとも次を保存する。

```text
system_metrics.csv
process_metrics.csv
occupancy_grid_node_metrics.csv
latency_summary.csv
iwasm.log
cartographer.log
rosbag.log
experiment_commit.txt
mros2_wasm_commit.txt
occupancy_grid_node_commit.txt
```

## 再現性

実験結果には、少なくとも以下を併記します。

- `experiment-20260718` のコミット
- `mros2-wasm` と再帰的サブモジュールのコミット
- Raspberry Pi のハードウェア、OS、電源測定器
- WASI SDK、WAMR、コンパイラのバージョン
- センサデータ、地図サイズ、解像度、実験時間
- ネットワーク構成と固定 IP アドレス

- 測定コマンド、測定器、サンプリング周期、集計方法
- 各試行の開始・終了時刻、ウォームアップの扱い、失敗や欠落のログ

## 結果の保存

結果は比較ケース、試行番号、コミットIDと対応付けます。生ログを加工前のまま保存し、集計表やグラフには使用したスクリプトと入力ファイルを明記します。起動失敗、メッセージ欠落、タイムアウトなどの失敗試行も削除せず、理由を記録します。

最低限、次のようなメタデータを各試行に残します。

```text
case: native_pi | wasm_occupancy_grid_pi
trial: <number>
experiment_commit: <sha>
mros2_wasm_commit: <sha>
wasm_sha256: <sha256>
iwasm_sha256: <sha256>
bag_sha256: <sha256>
started_at: <ISO-8601>
duration_sec: <number>
```
