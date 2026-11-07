# Stardew Valley Mods (Built)

ชุด Mod ที่ build แล้ว พร้อมใช้งานกับ [SMAPI](https://smapi.io/) — copy ลง `Stardew Valley\Mods` ได้ทันที

## Requirements

- Stardew Valley 1.6+ (Steam อัปเดตให้อัตโนมัติ)
- [SMAPI](https://smapi.io/) — script ติดตั้ง/อัปเดตให้เอง

## ติดตั้ง / อัปเดต (แนะนำ)

### วิธีที่ 1: Double-click (ง่ายสุด)

1. ดาวน์โหลด [`pull-mods-lasted.bat`](https://raw.githubusercontent.com/jarps9977/stardew-mods-builded/main/pull-mods-lasted.bat) (คลิกขวา > Save link as...)
2. Double-click `pull-mods-lasted.bat`

ไฟล์ `.bat` จะดึง `pull-mods-lasted.ps1` เวอร์ชันล่าสุดจาก GitHub มารันให้อัตโนมัติ เก็บ `.bat` ไว้ที่ไหนก็ได้ กดซ้ำเมื่อต้องการอัปเดต

> ถ้า Windows ขึ้น "Windows protected your PC" ให้กด **More info > Run anyway**

### วิธีที่ 2: Win+R (ไม่มีไฟล์ลงเครื่อง)

กด `Win+R` วางคำสั่งนี้ แล้วกด Enter:

```
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/jarps9977/stardew-mods-builded/main/pull-mods-lasted.ps1 | iex"
```

### วิธีที่ 3: PowerShell

```powershell
irm https://raw.githubusercontent.com/jarps9977/stardew-mods-builded/main/pull-mods-lasted.ps1 -OutFile "$env:TEMP\pull-mods-lasted.ps1"; powershell -ExecutionPolicy Bypass -File "$env:TEMP\pull-mods-lasted.ps1"
```

หรือถ้า clone/download repo มาแล้ว:

```powershell
powershell -ExecutionPolicy Bypass -File .\pull-mods-lasted.ps1
```

> **ถ้าเกมเปิดอยู่ script จะบังคับปิดเกมให้** (นับถอยหลัง 5 วินาที กด `Ctrl+C` เพื่อยกเลิก) — progress ที่ยังไม่ได้ save จะหาย

Script จะ:

1. **หา folder เกมอัตโนมัติ**: Steam (ทุก Library ใน `libraryfolders.vdf`) → GOG → path ทั่วไปทุก drive → ถ้าไม่เจอ จะเปิดหน้าต่างให้เลือก folder เกมเอง
2. **ติดตั้ง/อัปเดต SMAPI** เป็นเวอร์ชันล่าสุดจาก [GitHub releases](https://github.com/Pathoschild/SMAPI/releases) (ข้ามถ้าเป็นเวอร์ชันล่าสุดอยู่แล้ว)
3. **Sync Mods ให้ตรงกับ repo** (repo เป็นหลัก)
   - Folder Mod ที่มีอยู่แล้ว → อัปเดตไฟล์ (overwrite) รวมถึง **`config.json`**
   - Folder Mod ที่ยังไม่มี → สร้างใหม่
   - **Mod ที่ไม่ได้อยู่ใน repo** → ย้ายไป `Stardew Valley\Mods_backup\<วันเวลา>\`
   - ไฟล์เก่าค้างใน mod (เช่น `.dll` จากเวอร์ชันเก่า) → ย้ายไป backup เช่นกัน
   - ไม่แตะ `ConsoleCommands`, `SaveBackup` (มากับ SMAPI), folder ที่ขึ้นต้นด้วย `.` และ sub-folder `cache` / `data` / `saves` / `logs` ใน mod
4. **ตั้ง Steam Launch Options** (Steam เท่านั้น) เป็น `"<game>\StardewModdingAPI.exe" %command%` ถ้ายังไม่ได้ตั้ง
   - ต้องปิด Steam ระหว่างแก้ — script จะปิด Steam ให้เอง (ถ้าปิดปกติไม่ได้ภายใน 30 วินาที จะบังคับปิด) แล้วเปิดกลับ
   - backup ไฟล์เดิมไว้ที่ `localconfig.vdf.bak-<วันเวลา>`
5. **ให้ Steam ตรวจไฟล์เกม** (Verify integrity) — ดูความคืบหน้าในหน้าต่าง Steam

ขอสิทธิ์ Administrator อัตโนมัติ ถ้าไม่มีสิทธิ์เขียนใน `Program Files`

> ถ้ามี mod ที่ถูกย้ายออกแล้วอยากได้คืน ให้ย้าย folder จาก `Mods_backup\<วันเวลา>\` กลับเข้า `Mods`

### Options

| Parameter | Default | คำอธิบาย |
|---|---|---|
| `-ModsPath` | auto-detect | Folder Mods ปลายทาง (ระบุเองเพื่อข้ามการหาอัตโนมัติ) |
| `-Branch` | `main` | Branch ที่จะดาวน์โหลด |
| `-SkipSmapi` | off | ไม่ติดตั้ง/อัปเดต SMAPI |
| `-SkipValidate` | off | ไม่สั่ง Steam ตรวจไฟล์เกม |
| `-NoPause` | off | ไม่ต้องรอกด Enter ตอนจบ (สำหรับ automation) |

ตัวอย่าง (เกมติดตั้งที่ drive อื่น):

```powershell
powershell -ExecutionPolicy Bypass -File .\pull-mods-lasted.ps1 -ModsPath "D:\SteamLibrary\steamapps\common\Stardew Valley\Mods"
```

หรือผ่าน `.bat` (option ส่งต่อให้ `.ps1` ได้เหมือนกัน):

```bat
pull-mods-lasted.bat -ModsPath "D:\SteamLibrary\steamapps\common\Stardew Valley\Mods"
```

## ติดตั้งแบบ Manual

1. Download ZIP จาก `Code > Download ZIP`
2. แตกไฟล์ แล้ว copy ทุก folder ไปไว้ใน `Stardew Valley\Mods`

## Mod List

| Mod | Author | Version | คำอธิบาย |
|---|---|---|---|
| AutomateToolSwap | Trapyy | 1.6.1 | เลือก tool ที่ถูกต้องให้อัตโนมัติเมื่อคลิก |
| AutomaticGates | Rakiin aKa ScheKaa | 2.5.5 | เปิด/ปิดประตูรั้วอัตโนมัติ |
| Bundle Marker | jarukit | 1.1.0 | ทำเครื่องหมาย item ที่ต้องใช้ใน bundle, museum, shipping, quest |
| Content Patcher | Pathoschild | 2.9.1 | Framework สำหรับ content pack (`[CP]` mods) |
| Convenient Inventory | gaussfire | 1.6.1 | Quick stack เข้ากล่องใกล้ๆ, favorite item |
| Co-op Music | Gego | 1.0.0 | เครื่องเล่นเพลง YouTube แบบแชร์กันใน co-op |
| Crop Watering Bubbles Continued | aedenthorn, tem696969696969 | 0.2.12 | แสดง bubble เมื่อพืชยังไม่ได้รดน้ำ |
| Generic Mod Config Menu | spacechase0 / kittycatcasey | 1.16.0 | UI ตั้งค่า mod ในเกม |
| Gojo Outfit | Gego | 1.0.0 | Monster drop ชุด Gojo, ใส่ครบเซ็ตได้ bonus |
| Lookup Anything | Pathoschild | 1.55.0 | ดูข้อมูลทุกอย่างด้วยการกดปุ่ม |
| NPC Map Locations | Bouhm | 3.5.2 | แสดงตำแหน่ง NPC และผู้เล่นบนแผนที่ |
| Range Highlight | Jamie Taylor | 4.2.1 | Highlight ระยะของ scarecrow, sprinkler ฯลฯ |
| Tornado Warp | Gego | 1.0.0 | Return Scepter เรียกพายุหมุนยักษ์ ชาร์จ 3 วิก่อนวาร์ปกลับบ้าน เลือกสีได้ |
| Unlimited Void | Gego | 1.0.0 | ฆ่า monster ชาร์จเกจ แล้วกาง domain Unlimited Void |
| [CP] Satoru Gojo Kids Retexture | Cursedcure | 1.0.0 | เปลี่ยนหน้าตาลูกให้เหมือน Satoru Gojo (ต้องใช้ Content Patcher) |
| [CP] Satoru Gojo NPC | Cursedcure | 2.0.5 | เพิ่ม Satoru Gojo เป็น NPC (ต้องใช้ Content Patcher) |

> `ConsoleCommands` และ `SaveBackup` มากับ SMAPI อยู่แล้ว จึงไม่ได้รวมไว้ใน repo นี้

## Notes

- `CoopMusic/cache/` ไม่ได้รวมไว้ (เป็น cache เพลง จะสร้างใหม่เองตอนเล่น)
- Mod ของผู้พัฒนาอื่นเป็นลิขสิทธิ์ของผู้สร้างแต่ละคน — ดูต้นฉบับได้ที่ [Nexus Mods](https://www.nexusmods.com/stardewvalley)
