# 驗證紀錄

本次已核對 `LOFTLINES.lsp` 的來源 SHA-256、公開指令、UTF-8 解碼、忽略字串與行註解後的括號平衡，以及文件內部連結與媒體完整性。結果見 [validation-report.json](../metadata/validation-report.json)。

靜態檢查不能證明程式可正確載入或執行。這次未在 AutoCAD 做實機回歸，原碼問題仍依 [KNOWN_ISSUES](KNOWN_ISSUES.md) 處理。

## 重跑靜態檢查

Python 3.10 或更新版本，使用標準函式庫：

```text
python scripts/verify_repository.py
```

GitHub Actions 執行相同的靜態檢查，不執行 AutoCAD。

## 實機記錄

| 情境 | 結果 |
| --- | --- |
| AutoCAD 完整版本／組建與介面語言 | 待填 |
| 圖面單位、UCS、模型／紙空間、LISPSYS | 待填 |
| 依 README 的正常流程與輸出核對 | 待測 |
| Enter、Esc、無選取、無效物件 | 待測 |
| 錯誤後系統變數、Undo 與監聽狀態 | 待測 |
| 必要圖塊、屬性 Tag、動態參數 | 依本工具需求測試 |

[返回 README](../README.md)。
