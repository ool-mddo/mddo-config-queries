# mddo-config-queries

Batfish & Policy-parser 出力サンプル (参照/デモ説明用)
* See also: [システムコンポーネントとその関係](https://github.com/ool-mddo/playground/blob/main/doc/system_architecture.md#システムコンポーネントとその関係)

## mddo-fw

firewall(Juniper SRXクラスタ構成)を含むサンプルネットワークです。site-a/b/c の3拠点で構成され、各拠点に cr(HSRP/VRRP冗長ゲートウェイ), fw(クラスタペア), br(WAN接続ルータ), host を持ちます。

### Configuration (Input)

[mddo-fw network](https://github.com/ool-mddo/mddo-fw)参照 (firewall要件を含むサンプルconfig)
- 本リポジトリの[policies](./policies/firewall-policy-parser/configs/)に、パーサーへの入力として使用したコンフィグを同梱しています。
  - [configs](./policies/firewall-policy-parser/configs/mddo-fw/original_asis/)
- Layer1 topology は[mddo-bgp](#mddo-bgp)と同様に interface description 定義ベースのトポロジ管理です。

### Queries (Intermediate output)

[batfish-wrapper](https://github.com/ool-mddo/batfish-wrapper)で取得したクエリ出力: [queries](./queries/mddo-fw/original_asis/)

[mddo-bgp](#queries-intermediate-output)と同じクエリ([ip_owners.csv](./queries/mddo-fw/original_asis/ip_owners.csv), [interface_props.csv](./queries/mddo-fw/original_asis/interface_props.csv), [node_props.csv](./queries/mddo-fw/original_asis/node_props.csv), [sw_vlan_props.csv](./queries/mddo-fw/original_asis/sw_vlan_props.csv), [ospf_*_conf.csv](./queries/mddo-fw/original_asis/), [bgp_*_conf.csv](./queries/mddo-fw/original_asis/), [routes.csv](./queries/mddo-fw/original_asis/routes.csv), [named_structures.csv](./queries/mddo-fw/original_asis/named_structures.csv))に加えて、冗長ゲートウェイ(FHRP)の情報を取得しています。

|Target|Output|Note|
|------|------|----|
|HSRP設定|[hsrp_props.csv](./queries/mddo-fw/original_asis/hsrp_props.csv)|Interface, Group_Id, Virtual_Addresses, Priority, Preempt, Active|
|VRRP設定|[vrrp_props.csv](./queries/mddo-fw/original_asis/vrrp_props.csv)|同上|

mddo-bgp と同様、L1/L3トポロジ情報(edges_layer1.csv等)はトポロジ生成には使用していません。

### Firewall Policy (Intermediate output)

Firewallポリシ(ルール本体)のデータ取得についてはBatfishを利用せず[独自parser(firewall-policy-parser)](https://github.com/ool-mddo/firewall-policy-parser)を使用しています。([mddo-bgp](#bgp-policy-intermediate-output)の bgp-policy-parser に相当)

出力サンプル (最終的な出力のみで、BGPのようなベンダ依存のTTP中間出力はありません: firewall-policy-parser `v0.2.0` では vSRX config 飲みを対象としていてマルチベンダ対応を考慮していないため)
* [outputs](./policies/firewall-policy-parser/outputs/mddo-fw/original_asis/)

### Topology (Output data)

|Snapshot|Description|Topology|
|--------|-----------|--------|
|original_asis|Batfishクエリから生成した元トポロジ (全ノード)|[topology.json](./topologies/mddo-fw/original_asis/topology.json)|
|original_asis_conduit1|土管化トポロジ (blueprintの zoom0-layer3 に対応)|[topology.json](./topologies/mddo-fw/original_asis_conduit1/topology.json)|
|original_asis_conduit2|土管化トポロジ (blueprintの zoom1-layer3 に対応)|[topology.json](./topologies/mddo-fw/original_asis_conduit2/topology.json)|

- 各snapshotには、ネームスペース変換テーブル(`ns_convert_table.json`)も含みます。
  - See also: [ネットワークのモデル](https://github.com/ool-mddo/playground/blob/main/doc/network_model.md)
- original_asis には mddo-bgp 同様の BGP/OSPF 等のレイヤに加え、firewall属性・FHRP属性が付与されています。

### Refocus topology usecase (blueprint / conduit)

土管化 (refocus topology) ユースケースでは、検証に関係しない部分を集約して小さな(土管化した)トポロジを作ります。

* **blueprint snapshot** (入力): 「どのノード群をどう集約するか」を定義するデータ。[usecases/refocus_topology/mddo-fw](./usecases/refocus_topology/mddo-fw/)
  * 人が書く簡略定義 `topology-def.yaml` と、そこから生成した RFC8345 形式の `topology.json` で構成されます。
  * 粗さの異なる複数の network(zoom)を下層から順に定義します (`zoom0-layer3` → `zoom1-layer3` ...)。zoom N は直前の zoom (最下層は original_asis の layer3) のノードを `supports` で集約します。
  * 全ノードを網羅する必要はなく、定義されないノードは conduit から省略されます。
* **conduit snapshot** (出力): blueprint の各 zoom network ごとに、original_asis に対して1つずつ生成されるトポロジ。`original_asis_conduit<N>` の N は blueprint の network の並び順(1始まり)で、conduit1 = zoom0、conduit2 = zoom1 です。
  * 全てを再生成する際は既存の `original_asis_conduit*` を削除してから作り直します。つまり conduit の組は常に1つの blueprint から生成されたものです。

```
original_asis (topology.json)
  └─ blueprint (topology-def.yaml → topology.json)
       ├─ zoom0-layer3 ──→ original_asis_conduit1
       └─ zoom1-layer3 ──→ original_asis_conduit2
```

blueprint は2種類あり、どちらを使うかで生成される conduit の内容が変わります。

|Blueprint|Description|
|---------|-----------|
|[original_asis_blueprint1](./usecases/refocus_topology/mddo-fw/original_asis_blueprint1/)|site-a/site-b のみを対象 (site-c は省略)|
|[original_asis_blueprint2](./usecases/refocus_topology/mddo-fw/original_asis_blueprint2/)|site-c を含む|

* どちらも endpoint(`site-*-host-1/2`)は省略せず含め、gateway の `site-*-cr-1/2` は `site-*-cr` に集約します。
* zoom0: fw(クラスタペア)を `site-*-fw` に、br(WAN接続ルータ)を `site-*-wan-zone-rt` に集約します。
* zoom1: 各拠点の `site-*-wan-zone-rt` をさらに1つの `wan-zone-rt` に集約します。
* 本リポジトリの conduit1/2 は site-c を含むため、**blueprint2 から生成したもの**です (conduit1 は拠点ごとの `site-*-wan-zone-rt`、conduit2 は集約済みの `wan-zone-rt` を持ちます)。

その他の設定: [params.yaml](./usecases/refocus_topology/mddo-fw/params.yaml) (クラスタ構成のfirewallペア, containerlabノード定義)


## mddo-bgp

### Configuration (Input)

[mddo-bgp network](https://github.com/ool-mddo/mddo-bgp) 参照
- [Network device configs](https://github.com/ool-mddo/mddo-bgp/tree/main/original_asis/configs)
- [Layer1 topology](https://github.com/ool-mddo/mddo-bgp/blob/main/original_asis/batfish/layer1_topology.json)
  - See also: [物理トポロジデータの生成と編集](https://github.com/ool-mddo/playground/blob/main/demo/layer1_topology/README.md)

### Queries (Intermediate output)

[batfish-wrapper](https://github.com/ool-mddo/batfish-wrapper) (詳細は[bf_query_thrower.py](https://github.com/ool-mddo/batfish-wrapper/blob/main/src/bfwrapper/bf_query_thrower.py)) 参照

|Target|Query|Output|Note|
|------|-----|------|----|
|IP設定情報|[ip_owners](https://pybatfish.readthedocs.io/en/latest/notebooks/configProperties.html#IP-Owners)|[ip_owners.csv](./queries/mddo-bgp/original_asis/ip_owners.csv)||
|インタフェース設定|[interface_props](https://pybatfish.readthedocs.io/en/latest/notebooks/configProperties.html#Interface-Properties)|[interface_props.csv](./queries/mddo-bgp/original_asis/interface_props.csv)|一部の列のみ取得|
|ノード設定|[node_props](https://pybatfish.readthedocs.io/en/latest/notebooks/configProperties.html#Node-Properties)|[node_props.csv](./queries/mddo-bgp/original_asis/node_props.csv)||
|VLANパラメタ|[sw_vlan_props](https://pybatfish.readthedocs.io/en/latest/notebooks/configProperties.html#VLAN-Properties)|[sw_vlan_props.csv](./queries/mddo-bgp/original_asis/sw_vlan_props.csv)||
|OSPFプロセス設定|[ospf_proc_conf](https://pybatfish.readthedocs.io/en/latest/notebooks/configProperties.html#OSPF-Process-Configuration)|[ospf_proc_conf.csv](./queries/mddo-bgp/original_asis/ospf_proc_conf.csv)||
|OSPFインタフェース設定|[ospf_intf_conf](https://pybatfish.readthedocs.io/en/latest/notebooks/configProperties.html#OSPF-Interface-Configuration)|[ospf_intf_conf.csv](./queries/mddo-bgp/original_asis/ospf_intf_conf.csv)||
|OSPFエリア設定|[ospf_area_conf](https://pybatfish.readthedocs.io/en/latest/notebooks/configProperties.html#OSPF-Area-Configuration)|[ospf_area_conf.csv](./queries/mddo-bgp/original_asis/ospf_area_conf.csv)||
|BGPプロセス設定|[bgp_proc_conf](https://pybatfish.readthedocs.io/en/latest/notebooks/configProperties.html#BGP-Process-Configuration)|[bgp_proc_conf.csv](./queries/mddo-bgp/original_asis/bgp_proc_conf.csv)||
|BGPピア設定|[bgp_peer_conf](https://pybatfish.readthedocs.io/en/latest/notebooks/configProperties.html#BGP-Peer-Configuration)|[bgp_peer_conf.csv](./queries/mddo-bgp/original_asis/bgp_peer_conf.csv)||
|経路情報|[routes](https://pybatfish.readthedocs.io/en/latest/notebooks/routingTables.html#Routes)|[routes.csv](./queries/mddo-bgp/original_asis/routes.csv)|local,staticのみ参照|
|名前付きオブジェクト|[named_structures](https://pybatfish.readthedocs.io/en/latest/notebooks/configProperties.html#Named-Structures)|[named_structures.csv](./queries/mddo-bgp/original_asis/named_structures.csv)|BGPポリシの名前取得で利用|

当初L1/L3トポロジ情報 ([layer1_edges](https://pybatfish.readthedocs.io/en/latest/notebooks/topology.html#User-Provided-Layer-1-Topology), [layer3_edges](https://pybatfish.readthedocs.io/en/latest/notebooks/topology.html#Layer-3-Topology))も参照していましたが interface description 定義ベースのトポロジ管理に移行したので現在は使用していません。

トポロジ情報については[mddo-bgp network](https://github.com/ool-mddo/mddo-bgp)同梱の[トポロジデータ(layer1_topoollgy.json)](https://github.com/ool-mddo/mddo-bgp/blob/main/original_asis/batfish/layer1_topology.json)を参照。これは、interface description の情報→netbox→batfishインプット用のL1トポロジとして出力したものです。詳細は[playground](https://github.com/ool-mddo/playground/tree/main)にある、[物理トポロジデータの生成](https://github.com/ool-mddo/playground/blob/main/demo/layer1_topology/doc/operation.md)を参照してください。

### BGP Policy (Intermediate output)

BGPポリシ(ルール本体)のデータ取得についてはBatfishを利用せず[独自parser(bgp-policy-parser)](https://github.com/ool-mddo/bgp-policy-parser)を使用しています。

出力サンプル
* Input: [コンフィグ](./policies/bgp-policy-parser/configs/mddo-bgp/original_asis/)
* TTPによる中間出力(ベンダ依存)
  * [Cisco系](./policies/bgp-policy-parser/outputs/mddo-bgp/original_asis/cisco_ios_xr/)
  * [Juniper系](./policies/bgp-policy-parser/outputs/mddo-bgp/original_asis/juniper/)
* [標準化した最終的な出力](./policies/bgp-policy-parser/bgp_policies/mddo-bgp/original_asis/)

### Topology (Output data)
- [topology.json](./topologies/mddo-bgp/original_asis/topology.json)
  - See also: [ネットワークのモデル](https://github.com/ool-mddo/playground/blob/main/doc/network_model.md)

## mddo-ospf

### Configuration (input)

[mddo-ospf](https://github.com/ool-mddo/mddo-ospf)参照
- See also: [デモ:セグメント移転ユースケース](https://github.com/ool-mddo/playground/blob/main/demo/copy_to_emulated_env/doc/move_seg/introduction.md)

### Queries (Intermediate output)

- [queries](./queries/mddo-ospf/original_asis/)

### Topology (Output data)

- [topology](./topologies/mddo-ospf/original_asis/topology.json)

## pushed-configs

### Configuration (Input)

[pushed_configs](https://github.com/ool-mddo/pushed_configs)参照
- 検証用のトポロジをブランチで管理しています。ここにあるのは [202202demo2](https://github.com/ool-mddo/pushed_configs/tree/202202demo2)ブランチのコンフィグをもとにしたものです。
- See also: [リンクダウンシミュレーション](https://github.com/ool-mddo/playground/blob/main/demo/linkdown_simulation/README.md)

### Queries (Intermediate output)

- [queries](./queries/pushed_configs/mddo_network/)

### Topology (Output data)

- [topology](./topologies/pushed_configs/mddo_network/topology.json)

## batfish-test-topology

[batfish-test-topology](https://github.com/corestate55/batfish-test-topology)参照
- 複数のテスト用トポロジを含んでいます
- See also: [開発用テストネットワークの分析](https://github.com/ool-mddo/playground/blob/main/demo/linkdown_simulation/doc/test_network.md)

| Snapshot | Description | Input | Queries | Output |
| --- | --- | --- | --- | --- |
| l2_sample3 | L2構成 (2switch, 2vlan) | [configs](https://github.com/corestate55/batfish-test-topology/tree/develop/l2_sample3) | [Queries](./queries/batfish-test-topology/l2_sample3/) | [topology](./topologies/batfish-test-topology/l2_sample3/) |
| l2_sample4 | L2構成 (2switch, 2vlan, 1VRF) | [configs](https://github.com/corestate55/batfish-test-topology/tree/develop/l2_sample4) | [Queries](./queries/batfish-test-topology/l2_sample4/) | [topology](./topologies/batfish-test-topology/l2_sample4/) |
| l2_sample5 | L2構成 (sample4 + 同一L2/異なるVLAN IDでの接続) | [configs](https://github.com/corestate55/batfish-test-topology/tree/develop/l2_sample5) | [Queries](./queries/batfish-test-topology/l2_sample5/) | [topology](./topologies/batfish-test-topology/l2_sample5/) |
| l3_sample1a | L3構成, (複数 OSPF area, BGP, BGP対向再現) | [configs](https://github.com/corestate55/batfish-test-topology/tree/develop/l3_sample1a) | [Queries](./queries/batfish-test-topology/l3_sample1a/) | [topology](./topologies/batfish-test-topology/l3_sample1a/) |
| l3_sample1b | L3構成, (複数 OSPF area, BGP) | [configs](https://github.com/corestate55/batfish-test-topology/tree/develop/l3_sample1b) | [Queries](./queries/batfish-test-topology/l3_sample1b/) | [topology](./topologies/batfish-test-topology/l3_sample1b/) |
| l2l3_demo1 | L2_sample3 + ルータ (正常系) | [configs](https://github.com/corestate55/batfish-test-topology/tree/develop/l2l3_demo1) | [Queries](./queries/batfish-test-topology/l2l3_demo1/) | [topology](./topologies/batfish-test-topology/l2l3_demo1/) |
| l2l3_demo1a | L2_sample3 + ルータ (異常系: L3 IP重複, 複数prefix混在セグメント) | [configs](https://github.com/corestate55/batfish-test-topology/tree/develop/l2l3_demo1a) | [Queries](./queries/batfish-test-topology/l2l3_demo1a/) | [topology](./topologies/batfish-test-topology/l2l3_demo1a/) |
| l2l3_demo1b | L2_sample3 + ルータ (正常系, スイッチ間ループ) | [configs](https://github.com/corestate55/batfish-test-topology/tree/develop/l2l3_demo1b) | [Queries](./queries/batfish-test-topology/l2l3_demo1b/) | [topology](./topologies/batfish-test-topology/l2l3_demo1b/) |
| l2l3_demo1c | L2_sample3 + ルータ (異常系, スイッチ間クロス(同一L2/異VLAN ID)) | [configs](https://github.com/corestate55/batfish-test-topology/tree/develop/l2l3_demo1c) | [Queries](./queries/batfish-test-topology/l2l3_demo1c/) | [topology](./topologies/batfish-test-topology/l2l3_demo1c/) |
| l2l3_demo1d | L2_sample3 + ルータ (正常系, Standalone L2 segment) | [configs](https://github.com/corestate55/batfish-test-topology/tree/develop/l2l3_demo1d) | [Queries](./queries/batfish-test-topology/l2l3_demo1d/) | [topology](./topologies/batfish-test-topology/l2l3_demo1d/) |
| l2l3_sample3 | L2_sample3 + ルータ (正常系) | [configs](https://github.com/corestate55/batfish-test-topology/tree/develop/l2l3_sample3) | [Queries](./queries/batfish-test-topology/l2l3_sample3/) | [topology](./topologies/batfish-test-topology/l2l3_sample3/) |
| l2l3_sample3err | L2_sample3 + ルータ (異常系: 複数prefix混在セグメント) | [configs](https://github.com/corestate55/batfish-test-topology/tree/develop/l2l3_sample3err) | [Queries](./queries/batfish-test-topology/l2l3_sample3err/) | [topology](./topologies/batfish-test-topology/l2l3_sample3err/) |
| l2l3_sample3err2 | L2_sample3 + ルータ (異常系: L3 IPアドレス重複) | [configs](https://github.com/corestate55/batfish-test-topology/tree/develop/l2l3_sample3err2) | [Queries](./queries/batfish-test-topology/l2l3_sample3err2/) | [topology](./topologies/batfish-test-topology/l2l3_sample3err2/) |
| l2l3_sample3err3 | L2_sample3 + ルータ (異常系: L2ループ) | [configs](https://github.com/corestate55/batfish-test-topology/tree/develop/l2l3_sample3err3) | [Queries](./queries/batfish-test-topology/l2l3_sample3err3/) | [topology](./topologies/batfish-test-topology/l2l3_sample3err3/) |
