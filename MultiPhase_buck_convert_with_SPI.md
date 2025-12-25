# Multiphase Digital Buck Converter (9V → 1.5V)

本專題為 **全數位 multiphase synchronous buck converter** 設計，
目標為在 **9V → 1.5V，0.5A–1A load** 條件下運作。

系統採用 **4-phase interleaving 架構**，
每一相具備獨立 DPWM high / low gate，
相位電感並聯以降低電流漣波並分散應力。

---

## System Architecture

- 4-phase multiphase buck converter
- Digital control loop
- Shared counter with phase-shift DPWM
- Dither-enhanced duty resolution
- Deadtime-protected synchronous rectification

---

## Module Overview

### 1. Encoder (8-bit → 4-bit Error Quantizer)

輸出電壓誤差原本為 8-bit 數位量，
為降低硬體複雜度並避免 limit-cycle oscillation (LCO)，
設計一個 **Encoder** 將 error 量化為 **4-bit signed control code (-4 ~ +4)**。

功能：
- 降低控制器輸入解析度
- 提供誤差方向與強度
- 改善穩定性與硬體可實現性

---

### 2. Digital Compensator (LUT-based IIR / RST)

數位補償器以差分方程表示：

d[n] = d[n−1] + A(e[n]) + B(e[n−1]) + C(e[n−2]) + D(e[n−3])

特點：
- error 為 4-bit signed
- A/B/C/D 由 **Lookup Table (LUT)** 查表實現
- 無乘法器，硬體成本低
- 10-bit duty 輸出，後接 DPWM

內含：
- error delay line
- accumulator
- duty limiter (0 ~ 0.95)

---

### 3. DPWM with Dither

DPWM counter 為 7-bit (PERIOD = 128)，
但控制器輸出為 10-bit duty。

為保留低位解析度，使用 **3-bit dither 技術**：

- base duty：d_n_input[9:3]
- fractional duty：d_n_input[2:0]
- 8 週期內平均達成近似 10-bit 解析度
- 降低 steady-state LCO

---

### 4. Deadtime DPWM (Per-Phase)

每一相皆包含：
- duty_high：high-side gate
- duty_low：low-side gate

Deadtime DPWM 架構包含：

1. Phase-shift counter  
   phcnt = (count + PHASE_OFF) mod PERIOD

2. Duty comparator  
   產生理想 want_hs / want_ls

3. Deadtime state machine  
   - HS ↔ LS 切換時插入 DEADTIME
   - 避免 shoot-through

---
## SPI Control Interface (Register Access)

本專題加入 SPI 作為外部控制/讀回介面，用來在不重新綜合 RTL 的情況下：
- 寫入控制參數（enable/mode/phase/deadtime/duty…）
- 更新補償器/DPWM 相關設定（dither、limit、divider…）
- 讀回目前暫存器內容，方便 debug 與系統整合

### SPI Modules

- `spi_master.v`  
  SPI Master（通常給 testbench / FPGA / SoC 端使用），產生 SCK/MOSI/CS，並讀回 MISO。

- `spi_slave.v`  
  SPI Slave（Mode0 常見：CPOL=0, CPHA=0）  
  負責：接收 MOSI frame、解析 cmd/addr、完成 write 或 read 回傳。

- `spi_reg.v`  
  Register File / Address Decode  
  將 SPI 寫入的資料落到內部控制暫存器（reg0~reg5），並提供讀回資料給 SPI slave。

- `top.v` / `SPI.v`（依你的命名）  
  系統整合：把 SPI 寫入的設定接到 multiphase buck converter 的 encoder/compensator/dither/dpwm/deadtime 等模組。

### Recommended Register Map (Example)

> 你可以依照目前 RTL 實作調整。下面是一個「好維護」的常用分法：

- **reg0: MODE/ENABLE/PHASE + deadtime + manual duty**
  - enable、mode、相位設定、deadtime、手動 duty override 等
- **reg1: Encoder parameters**
  - center/step/threshold（如果 encoder 有可調參數）
- **reg2: Clock Divider / Counter parameters**
  - PWM base clock divider、counter 相關設定
- **reg3: Compensator coefficient / LUT select**
  - LUT bank selection、係數表切換（若有多組）
- **reg4: Limiter / protection**
  - duty 上下限、soft-start、保護閥值
- **reg5: Dither / deadtime fine-tune**
  - dither enable、pattern 相關、deadtime 微調等

### SPI Transaction (Example)

- WRITE：`CS=0` 後送入 `[CMD][ADDR][DATA]`（MSB first），最後 `CS=1` 完成寫入  
- READ ：`CS=0` 後送入 `[CMD][ADDR][DUMMY]`，並在後段 clocks 由 `MISO` 讀回資料

（實際 frame 長度與 cmd/addr/data 位數請以你的 `spi_slave.v`/`spi_reg.v` 定義為準）


## Key Features

- 4-phase interleaving
- LUT-based digital compensator
- Dither-enhanced duty resolution
- Safe deadtime insertion
- Hardware-friendly design (no multipliers)

---

## Target Specification

| Item | Value |
|-----|------|
| Vin | 9 V |
| Vout | 1.5 V |
| Load Current | 0.5 – 1 A |
| Phases | 4 |
| Control | Fully Digital |

---

## Tools

- Verilog / SystemVerilog
- RTL simulation
- (Planned) Verilog-A ADC + mixed-signal co-sim
- Sky130 / OpenLane (future tapeout)

