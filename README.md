# Burst Breaker

3〜5分で遊べる、ブロック崩し型ローグライトの試作です（Godot 4.6）。

指を下に引いて離すと玉を発射します。パソコンではマウスで操作できます。

## 実行

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

## 確認

ルールのテストとバランスの集計です。

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tests/run_tests.gd
```

実際の入力イベントで通しプレイし、スクリーンショットと `report.json` を保存します。

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . --always-on-top -- --verify="$PWD/verify-output"
```

## 構成

- `sim/game_sim.gd`: ゲームのルール（描画に依存しない）
- `main.gd`: 画面遷移、入力、描画、エフェクト、効果音、通しプレイの確認
- `i18n.gd`: 表示テキスト（日本語が基本で、英語も選べる）
- `save_data.gd`: 設定と記録の保存
- `tests/run_tests.gd`: テストと自動プレイのバランス集計
