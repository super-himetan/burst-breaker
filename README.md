# Burst Breaker

3〜5分で遊べる、ブロック崩し型ローグライトの試作です（Godot 4.6）。

指を下に引いて離すと玉を発射します。パソコンではマウスで操作できます。

## やり込み要素

- 強化56種（進化8種を含む）と、実績による段階的な解放
- 玉8種、特殊ブロック7種、ボス2体
- コインで買える永続強化のショップ
- 上限のない難易度と、転生による星の倍率
- 実績118個と図鑑

## 実行

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

## 確認

ルールとデータのテストです。

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tests/run_tests.gd
```

実際の入力イベントで通しプレイし、スクリーンショットと `report.json` を保存します。

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . --always-on-top -- --verify="$PWD/verify-output"
```

ボットで長期プレイを模擬します。`perks` と `balls` で強化と玉の強さも比較できます。

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tests/balance.gd -- campaign 100 1
```

## 構成

- `sim/game_sim.gd`: ゲームのルール（描画に依存しない）
- `main.gd`: 画面遷移、入力、ゲーム画面、エフェクト、効果音
- `i18n.gd`: 表示テキスト（日本語が基本で、英語も選べる）
- `save_data.gd`: 設定と記録の保存
- `menus.gd`: ゲーム以外の各画面
- `verify.gd`: 実際の入力で全画面を通す確認
- `data/`: 強化、玉、ショップ、難易度、実績の定義
- `tests/run_tests.gd`: ルールとデータのテスト
- `tests/balance.gd`: ボットによる長期プレイと強さの比較
