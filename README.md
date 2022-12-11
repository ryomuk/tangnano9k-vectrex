# tangnano9k-vectrex
Tang Nano 9K top level module for vectrex

## 概要
- Tang Nano 9K用のトップレベルモジュールです．
- SourceForge( https://sourceforge.net/projects/darfpga/files/Software%20VHDL/vectrex/ )にあったDE10-lite用のソースを改変して作りました．
- README.TXTにあように，下記のことを理解した上でご使用下さい．
```
- Educational use only
- Do not redistribute synthetized file with roms
- Do not redistribute roms whatever the form
- Use at your own risk
```
## コンパイル方法
1. SourceForgeにある vhdl_vectrex_rev_0_2_2018_06_12.zip を展開する．
2. 展開してできた下記フォルダを，vectrex_project/src/に中身ごとコピーする．
```
cp -a rtl_dar rtl_jkent rtl_mikej rtl_pace vectrex_project/src/
```
3. ROMデータのvhdlファイルを用意して，romフォルダを作成してそこに置く．
```
mkdir vectrex_project/src/rom
cp vectrex_exec_prom.vhd vectrex_project/src/rom/ (必須)
cp vectrex_scramble_prom.vhd vectrex_project/src/rom/ (ゲームROMデータの例)
```
4. Gawin EDAでvectrex_project.gprjをビルドする
(ROMデータのファイルは，プロジェクトに適宜追加・削除して下さい．)

## ROMデータについて
- 必要なROMデータは何らかの方法で入手して，オリジナルのパッケージに含まれるREADME.TXTに従ってvhdlファイルを作成して下さい．
- romの名前，サイズに応じて，rtl_dar/vectrex.vhdの修正が必要です．

## 周辺回路について
- VGA出力，音声出力，キー入力は，hardware/tangnano9k-vectrex-peri-schematics.pdf の回路で動きました．
- たまたま手元にあった部品を使って作っただけなので，これが推奨回路というわけではありません．

## その他
- 27MHzのクロックを25MHzとして使っています．Tang NanoのPLLで25MHzのクロックが作れるかもしれないのでその方がいいかも．(私はPLLの使い方を知らないのと，IPを使いたくなかったので27MHzのクロックのまま使っています．)

