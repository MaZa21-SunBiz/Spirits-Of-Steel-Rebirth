# Production Menu Specification & Guide

A structured, flat, and intuitive sidebar menu for domestic production, financial overviews, political laws, military command, general recruitment, and foreign diplomacy in **Spirits of Steel: Rebirth**.

---

## 📐 Layout & Visual Design

- **Position & Dimensions**: Left-aligned floating panel (`400px` width, full-height dynamically adjusted to viewport).
- **Theme Style**: Flat Dark Minimalist (`COLOR_BG: #0A0A0D`, `COLOR_PANEL: #1A1A1F`, `COLOR_ACCENT: #D97326`).
- **Collapsible Drawer**: Toggle button (`◀` / `▶`) at top right allowing players to collapse the panel to inspect the tactical world map.

---

## 🗂️ Core Navigation Tabs

| Tab Icon | Name | Primary Functions |
| :--- | :--- | :--- |
| 🏭 **IND** | Industry & Financials | National financial overview, construction, raw materials market & trade deals |
| ⚔️ **MIL** | Military Command | Military command overview, division recruitment, training queue, deployment depot |
| ⚖️ **LAWS** | Politics & Laws | Military conscription draft laws, cabinet political decisions |
| 💼 **GENS** | Generals | General recruitment (50 PP), stat viewing, troop assignment/dismissal |
| 🌐 **DIP** | Diplomacy | Foreign relation status, peace pacts, aid gifts, military spying, war declarations |

---

## ⚙️ Detailed Module Architecture

### 1. 🏭 Industry & Financials Tab (`IND`)
- **National Financial Overview**:
  - **Gross Revenue**: Total daily cash from provincial GDP + Factories.
  - **Daily Expenses**: Breakdown of Army Maintenance, Active Construction, and Market Subscriptions/Imports.
  - **Net Cash Flow**: Net daily cash surplus or deficit (`+$X/day` or `-$Y/day`).
  - **Industrial Output**: Total factories and active construction slots.
- **Infrastructure Builder**:
  - `🔨 FACTORY ($1,000/d • 5 days)`: Costs $1,000/day for 5 days ($5,000 total). Adds +1 Factory & +2 Construction Slots on completion.
  - `⚓ NAVAL PORT ($100/d • 5 days)`: Costs $100/day for 5 days ($500 total). Adds +1 Port & unlocks maritime crude oil extraction on completion.
- **Active Construction Projects**:
  - Displays each project with target location, daily cost (`-$1,000/d`), days remaining, and visual progress bar.
- **Global Raw Materials Market**:
  - **Steel & Crude Oil**: Real-time market spot price tracking.
  - **Instant Transactions**: `BUY 5` or `SELL 5` buttons.
  - **Recurring Subscriptions**: Adjust daily automated flow (`-1` / `+1` per day).
- **Active Trade Deals**:
  - View running import/export contracts with cancel options (`×`).

### 2. ⚔️ Military Command Tab (`MIL`)
- **Military Command Overview**:
  - **Mobilized Servicemen**: Total active troops in field + training reserves.
  - **Daily Army Maintenance**: Total daily cash spend to keep active divisions supplied (`-$X/day`).
  - **Realistic Manpower Reserves**:
    - **Eligible Population**: `Total Population * Draft Ratio` (e.g. Volunteer 0.5%, Limited Draft 1.5%, Total Draft 4.0%).
    - **Available Reserves**: `Eligible Manpower - Mobilized Troops`.
- **Division Recruitment**:
  - **Division Types**: Infantry (1,000 men), Tank (500 men + 50 steel + 50 oil), Artillery (800 men + 30 steel).
  - **Batch Size Controls**: Incremental batch selector (`-` / `+` from 1 to 10).
  - **Training Queue**: Displays active production batches with remaining training days and progress bars.
- **Deployment Depot**:
  - Displays completed divisions waiting in reserve.
  - Allows selecting target province (`📍 SELECT PROVINCE`) or deploying directly (`🚩 DEPLOY BATCH`).

### 3. ⚖️ Politics & Laws Tab (`LAWS`)
- **Conscription Draft Ratio**: Displays current active military manpower ratio & economy penalties.
- **Draft Laws Selection**:
  - `Volunteer Only`: 0.5% manpower ratio, 0% penalty, 0 PP cost.
  - `Limited Draft`: 1.5% manpower ratio, 15% penalty, 150 PP cost.
  - `Total Draft`: 4.0% manpower ratio, 50% penalty, 150 PP cost.
- **Cabinet Decisions**:
  - `Stability Campaign` (50 PP): +15% Stability.
  - `War Support Rally` (50 PP): +15% War Support.
  - `Industrial Effort` (100 PP): Adds 1 Factory for $5,000 cash.

### 4. 💼 Generals Management Tab (`GENS`)
- **Recruitment**: Hire new command generals for 50 Political Power (PP).
- **General Cards**:
  - **Level & Attributes**: Attack bonus (`⚔️`), Defense bonus (`🛡️`), Logistics savings (`📦`).
  - **Troop Assignment**: Dropdown menu listing unassigned army stacks; single-click assignment and dismissal.

### 5. 🌐 Foreign Diplomacy Tab (`DIP`)
- **Relations Indicator**: Visual progress bar showing standing with target nation (0–100).
- **Diplomatic Actions**:
  - `Sign Non-Aggression Pact` (50 PP, requires relation ≥ 50).
  - `Send Financial Aid Gift` ($5,000 cash, boosts relations).
  - `Spy on Military` (25 PP, reveals total enemy division count & economic status).
  - `Declare War` (Initiates hostile military state).

---

## 🛠️ Code Structure & Best Practices

- **Flat Event Dispatching**: UI signals directly trigger `CountryManager`, `WarManager`, or `GameState` without intermediate state fragmentation.
- **Clean Component Recreation**: Responsive `_refresh_ui()` routine rebuilds current active tab content without memory leaks.
- **Top-Bar & Map Integration**: Automatically sets top-level canvas positioning and interacts with map rendering layers when selecting provinces or building infrastructure.
