# Nahj al-Balagha — Urdu translation repair notes (1.21.1)

## What was wrong
1. **Mirrored text.** Some paragraphs of `balaghatext.UR` were stored with the
   letters of each connected word reversed (a visual-order/logical-order
   mix-up in the original import): `ںیم` = میں, `ہیلع` = علیہ, `ےلہپ` = پہلے.
   Rows with this fault: 31, mostly Khutba 4–10 (rows 66–89), the Radi note of
   Khutba 31 (row 221 and the tail of 220) and rows 697/698 and 701–723 (Khutba 103–106).
2. **Stray fragments** from the same fault (`تق`, `کت`, `تع`, `تل`, `لُک`…) in
   rows 349–379 and 631–646, and a few mirrored short words (`افدئہ`,
   `اہکں`, `اہمترے`, `اہلل`, `کشیب`, `ششخب`).
3. **`مت` for `تم`** in rows 349, 353, 358, 363, 371, 374 and 375 (Khutba 57–62).
   In row 349 the swap reversed the meaning of an instruction.
4. **Split headers.** The header "(یہ امیر المومنین علیہ السلام کا ایک کلام ہے)" and
   the occasion line were cut mid-sentence and the tail was stored in the next
   row (sermons 11–37, 24 headers); the first words of the body were glued to
   the end of the previous occasion row in ~30 places.

## How it was repaired
- Mirrored rows: decoded with a dictionary built from the other (clean) Urdu
  databases of the app, then **every paragraph was proofread against the Arabic
  text** and rewritten by hand where the decoder was ambiguous (وقت/قوت,
  بجو/وجب, ہو/وہ, بنا/ابن…). Source brackets "[ ]" were kept.
- Nothing was translated from scratch; no new wording was added except the
  minimal words needed to restore the broken ones.
- The Fehmul Fasaha (Drive) database carries the same fault, so it could not
  be used as a replacement source.

## Rows changed
- Khutba 4: IDs 66, 67
- Khutba 5: IDs 69, 70, 71, 72
- Khutba 6: IDs 74, 75, 76
- Khutba 7: IDs 78, 79
- Khutba 8: IDs 81, 82, 83
- Khutba 9: IDs 85, 86
- Khutba 10: IDs 88, 89
- Khutba 11: IDs 91, 92, 93
- Khutba 12: IDs 96, 97
- Khutba 13: IDs 101, 102, 103
- Khutba 14: IDs 112, 113
- Khutba 15: IDs 115, 116, 117
- Khutba 16: IDs 119, 120, 121
- Khutba 17: IDs 129, 130
- Khutba 18: IDs 136, 137, 138
- Khutba 19: IDs 141, 142
- Khutba 20: IDs 146, 147
- Khutba 21: IDs 150, 151
- Khutba 22: IDs 154, 155
- Khutba 23: IDs 158, 159, 164, 165
- Khutba 24: IDs 168, 169
- Khutba 25: IDs 171, 172
- Khutba 26: IDs 184, 185, 186, 187, 188, 189
- Khutba 27: IDs 191, 192
- Khutba 28: IDs 200, 201, 203, 204
- Khutba 29: IDs 208, 209
- Khutba 31: IDs 218, 219, 220, 221
- Khutba 32: IDs 223, 224, 225
- Khutba 33: IDs 233, 234, 235
- Khutba 34: IDs 242, 243
- Khutba 35: IDs 249, 250, 251
- Khutba 36: IDs 255, 256
- Khutba 37: IDs 259, 260
- Khutba 39: IDs 267, 268, 269
- Khutba 40: IDs 273, 274
- Khutba 41: IDs 279, 280
- Khutba 42: IDs 282, 283
- Khutba 43: IDs 288, 289
- Khutba 44: IDs 294
- Khutba 51: IDs 323, 324
- Khutba 53: IDs 332, 333
- Khutba 55: IDs 340, 341
- Khutba 56: IDs 344, 345
- Khutba 57: IDs 348, 349
- Khutba 58: IDs 353
- Khutba 59: IDs 358, 361, 363
- Khutba 60: IDs 368
- Khutba 61: IDs 371
- Khutba 62: IDs 374, 375, 376
- Khutba 63: IDs 379
- Khutba 69: IDs 409, 410, 411
- Khutba 70: IDs 415, 416
- Khutba 71: IDs 423
- Khutba 72: IDs 427, 428
- Khutba 73: IDs 431, 432
- Khutba 74: IDs 435, 436
- Khutba 75: IDs 438, 439
- Khutba 76: IDs 445, 446
- Khutba 77: IDs 452, 453
- Khutba 78: IDs 458, 459
- Khutba 79: IDs 463, 464
- Khutba 80: IDs 467, 468
- Khutba 81: IDs 472, 473
- Khutba 89: IDs 577
- Khutba 95: IDs 631, 633, 634, 635, 636
- Khutba 96: IDs 638, 639
- Khutba 97: IDs 643, 646
- Khutba 98: IDs 648, 649
- Khutba 99: IDs 655, 656
- Khutba 103: IDs 697, 698
- Khutba 104: IDs 701, 702, 703, 706
- Khutba 105: IDs 713, 714
- Khutba 106: IDs 719, 722, 723
- Khutba 107: IDs 739
- Khutba 113: IDs 792, 793
- Khutba 116: IDs 816
- Khutba 120: IDs 838
- Khutba 122: IDs 854, 855
- Khutba 126: IDs 885, 886
- Khutba 127: IDs 895, 896, 898
- Khutba 130: IDs 913, 914, 915, 916, 917
- Khutba 131: IDs 920, 921, 922, 923, 928, 929, 930
- Khutba 132: IDs 932, 933
- Khutba 133: IDs 937, 938
- Khutba 141: IDs 986
- Khutba 189: IDs 1443, 1444
- Khutba 197: IDs 1570
- Maktoob 53: IDs 2232, 2233, 2303
- Hikmat 96: IDs 2711, 2712

## Known residual issues (not changed)
- Some words are still glued together in the original translation
  («زیادہبلیغ», «پاسشفاعت»). They are readable and left alone.
- Rows 2486/2487, 3612/3613 and a few more still have an occasion line cut
  across two rows; the text is complete and readable.
- Row 933 (and its siblings) still ends with "…مشورہ" in the source.
- Reviewing the translation once more against a printed edition is recommended
  before calling the text final.

Re-run `python3 scripts/verify_corpus.py` after any change to the database.
