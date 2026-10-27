# LOFTLINES 兩曲線間插值

![LOFTLINES](assets/banner.svg)

[工具儲存庫](https://github.com/whos-dwg/CadLISP-LOFTLINES) · [全部工具索引](https://github.com/whos-dwg/CadLISP-Index)

在兩條邊界曲線間建立指定數量的中間線，依來源種類輸出 LINE、LWPOLYLINE 或 SPLINE。

| 項目 | 內容 |
| --- | --- |
| 指令 | `LOFTLINES` |
| 檔案 | [LOFTLINES.lsp](lsp/LOFTLINES.lsp) |
| 分類 | 幾何處理 |
| 狀態 | 來源快照，實機回歸待完成 |
| 授權 | [MIT](LICENSE)，Copyright (c) 2026 whos-dwg |

[安裝](#安裝) · [操作](#操作) · [相依與設定](#相依與設定) · [已知問題](docs/KNOWN_ISSUES.md) · [驗證紀錄](docs/VALIDATION.md)

## 安裝

以 Windows 桌面版 AutoCAD 為目標。原碼使用的 Visual LISP／ActiveX、DCL 或原生命令，需在目標 AutoCAD 版本分別確認；尚未做整包年份、LT、Mac 或其他 CAD 的相容性認證。ActiveX 的平台限制見 [Autodesk](https://help.autodesk.com/cloudhelp/2026/ENU/AutoCAD-AutoLISP/files/GUID-A0459510-CE7A-4206-9EAA-E25AAB569B20.htm)。

1. 下載並解壓縮本工具到固定位置，先開啟測試圖面。
2. 依公司環境把 `lsp` 資料夾加入需要的支援搜尋路徑與受信任位置。
3. 輸入 `APPLOAD`，載入 `LOFTLINES.lsp`；關閉視窗後輸入 `LOFTLINES`。

也可使用完整路徑單獨載入；下列路徑需依實際位置修改：

```lisp
(load "C:/CAD/CadLISP-LOFTLINES/lsp/LOFTLINES.lsp")
```

完成驗證後，可將這支 LISP 加入 APPLOAD 的 Startup Suite。請維持既定的 SECURELOAD 政策，使用受信任位置處理載入限制。[SECURELOAD 說明](https://help.autodesk.com/cloudhelp/2026/ENU/AutoCAD-Core/files/GUID-541566C6-2738-49DD-87C3-C1490E924A02.htm)。

## 操作

1. 輸入 `LOFTLINES`，依序選取兩條邊界曲線。
2. 輸入中間曲線數量，按 Enter 使用 5。
3. 檢查曲線方向、插值結果與目前圖層。

## 相依與設定

選取兩個不同、可由曲線 API 讀取的邊界物件。

圖面影響：新增中間線，保留邊界來源。

## 行為與限制

LINE＋LINE 輸出 LINE；直線兩頂點組合輸出兩頂點 LWPOLYLINE；較複雜線段／聚合線組合使用取樣聚合線；涉及真正曲線時輸出 SPLINE。不是 3D LOFT 實體或曲面建模指令。

## 來源與授權

本工具依維護者確認為自行從零撰寫，或以 AI 協作從零開發。程式與本次文件採 [MIT 授權](LICENSE)，允許使用、修改與再散布，須保留授權及著作權聲明。詳細來源紀錄見 [provenance.json](metadata/provenance.json)。

## 回報與維護

回報時附 AutoCAD 完整版本、命令列錯誤與去識別的重現範例。修改前請閱讀 [CONTRIBUTING](CONTRIBUTING.md)；發行步驟見 [PUBLISHING](docs/PUBLISHING.md)。本工具可獨立維護、下載及發布，不依賴其他 CadLISP 工具儲存庫。
