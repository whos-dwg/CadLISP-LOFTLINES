# LOFTLINES 首次預覽發行說明草稿

在兩條邊界曲線間建立指定數量的中間線，依來源種類輸出 LINE、LWPOLYLINE 或 SPLINE。

- 指令：LOFTLINES。
- 相依與設定：選取兩個不同、可由曲線 API 讀取的邊界物件。
- 驗證：完成來源與文件靜態檢查；AutoCAD 實機回歸待完成。
- 已知事項：LINE＋LINE 輸出 LINE；直線兩頂點組合輸出兩頂點 LWPOLYLINE；較複雜線段／聚合線組合使用取樣聚合線；涉及真正曲線時輸出 SPLINE。不是 3D LOFT 實體或曲面建模指令。
- 授權：MIT，Copyright (c) 2026 whos-dwg。

本次保留來源位元組；發布時請按實際修補及測試結果更新這份說明。[完整操作](README.md)。
