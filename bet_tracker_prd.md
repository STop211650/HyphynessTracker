# Product Requirements Document (PRD)

## 0. Revision History
| Date | Version | Author | Notes |
|------|---------|--------|-------|
| 2025-06-11 | 1.0 | ChatGPT | Initial consolidated PRD with screenshot-to-settle flow |

---

## 1. Purpose
Build a cross-platform system that lets a user **capture a sportsbook screenshot, type the bettors and their stakes, and automatically track everyone’s pending and settled wagers**. The system stores bets in Supabase, computes each participant’s share of wins/losses, and surfaces outstanding balances in a web portal.

## 2. Scope & Goals
1. **Bet Ingestion** (macOS + iOS)  
   * Screenshot ➜ vision AI parses risk, to-win, odds, status, ticket #.  
   * User inputs bettors + individual stakes (supports uneven splits).
2. **Database Ledger**  
   * Normalize bets, legs, and participants in Supabase.  
   * Maintain per‑user running totals and unpaid balances.
3. **Manual Settlement**  
   * Pending bets remain until a *result* screenshot is uploaded.  
   * Edge Function matches by `ticket_number`, updates status & payouts.
4. **Portal UI** (Lovable web app)  
   * Dashboards for Pending, Won, Lost.  
   * User ledger with outstanding balances & payment recording.
5. **Payments & Exports**  
   * Mark payouts as paid, log transfers, download CSV.
6. **Admin & Security**  
   * Auth via Supabase; RLS so users see only their group’s bets.

## 3. Personas
| Persona | Needs |
|---------|-------|
| **Primary User “Sam”** | Quickly upload slips, see who owes what, record payments |
| **Friend “Alex”** | View own standing without seeing other groups |
| **Future Group Admin** | Invite friends, manage their own ledger |

## 4. User Stories
1. *As Sam*, I can press ⌥⌘B (mac) or share a screenshot (iOS) to log a new bet.  
2. *As Sam*, I can later upload a result screenshot to settle the pending bet.  
3. *As Alex*, I can see my total staked, returned, and outstanding balance.  
4. *As Sam*, I can mark balances paid when cash/Venmo is exchanged.  
5. *As Sam*, I can export a CSV for tax season.

## 5. Functional Requirements

### 5.1 Capture Flow

| Step | macOS | iOS |
|------|-------|-----|
| Screenshot | Native utility into watched folder | Share Sheet input |
| Trigger | Menu‑bar app + ⌥⌘B | Shortcut “Add Bet” |
| Input | Prompt text → names & stakes | Shortcut text box |
| Upload | POST `/add-bet` | Same |

### 5.2 Edge Functions

| Function | Method | Responsibility |
|----------|--------|----------------|
| `add-bet` | POST | Vision parse, text split, create bet rows (status = pending) |
| `settle-bet` | POST | Vision parse *result* screenshot, match `ticket_number`, update status & payouts |
| `record-payment` | POST | Insert `payments` row, toggle `is_paid` |
| `export-csv` | GET | Stream CSV of bets/payments by filter |

### 5.3 Vision Extraction Contracts

```jsonc
// Creation
{
  "sportsbook": "Bovada",
  "ticket_number": "1234567890",
  "type": "parlay",
  "odds": "+425",
  "risk": 100.00,
  "to_win": 425.00,
  "status": "pending",
  "legs": [
    { "event": "NYK @ IND", "market": "ML", "selection": "Knicks", "odds": "-150" }
  ]
}

// Settlement
{
  "ticket_number": "1234567890",
  "status": "won" // won | lost | void
}
```

### 5.4 Data Model (Postgres)

```sql
-- Core tables
users (
  id          uuid primary key,
  name        text unique,
  created_at  timestamptz default now()
);

bets (
  id             uuid primary key,
  ticket_number  text unique,
  sportsbook     text,
  type           text,
  status         text,
  risk           numeric,
  payout_total   numeric,
  odds           text,
  placed_at      timestamptz default now(),
  settled_at     timestamptz
);

bet_legs (
  id        uuid primary key,
  bet_id    uuid references bets(id),
  event_id  text,
  market    text,
  selection text,
  odds      numeric,
  result    text
);

bet_participants (
  bet_id     uuid references bets(id),
  user_id    uuid references users(id),
  stake      numeric,
  payout_due numeric default 0,
  is_paid    boolean default false,
  primary key (bet_id, user_id)
);

payments (
  id            uuid primary key,
  bet_id        uuid references bets(id),
  from_user_id  uuid references users(id),
  to_user_id    uuid references users(id),
  amount        numeric,
  note          text,
  paid_at       timestamptz default now()
);
```

Views: `v_user_ledger`, `v_user_balance` for quick ledger and outstanding balance queries.

### 5.5 Business Rules
1. **Stake sum must equal `risk`**; otherwise request user correction.  
2. **Bet settles only once**; subsequent attempts rejected.  
3. **Pro‑rata payouts:** `payout_due = stake / risk × to_win` (won) else 0.  
4. **Payments** reduce outstanding balance but never alter historical bet rows.  
5. **RLS** ensures users see only bets where they’re a participant or admin.

## 6. Non‑Functional Requirements

| Category | Target |
|----------|--------|
| Edge Function latency | ≤ 3 s P95 for typical slip |
| Vision cost budget | ≤ $0.01 per call |
| Browser support | Latest Chrome, Safari; iOS PWA |
| Security | API keys in Supabase secrets; images encrypted at rest |

## 7. UI / UX Overview
1. **Dashboard** – Card list with status filters & aging badges (> 36 h unresolved ⇒ red).  
2. **Bet Detail Drawer** – Legs, participants, *Settle via Screenshot* button.  
3. **Ledger** – Outstanding balances, “Record Payment” modal.  
4. **CSV Export** – Date‑range picker ➜ download.

## 8. System Architecture

```
[mac Menu‑Bar App]   [iOS Shortcut]
        \                /
         POST /add-bet  ←—— Supabase Edge Functions ——→  Postgres (RLS)
                            ↕
                     Lovable / Next.js Frontend
```

## 9. Open Items & Future Enhancements
1. Grace‑period threshold configurable per user?  
2. Fallback match when ticket # missing (manual picker)?  
3. Bulk‑slip parsing (multiple tickets in one screenshot).  
4. Group self‑onboarding & role‑based admin controls.

## 10. Milestones

| Offset | Deliverable |
|--------|-------------|
| **D+1** | Tables, RLS, stub `add-bet` |
| **D+3** | Vision extraction MVP (10 sample slips) |
| **D+5** | macOS menu‑bar + iOS Shortcut ingestion |
| **D+7** | Lovable dashboard & manual settlement |
| **D+9** | Payments + CSV export |
| **D+12** | Closed beta with friends |

---

*End of Document*
