# Personal Ledger — Android App (V1.0.0) — Technical Architecture & System Documentation

An investor-grade master document detailing the architectural design, system flows, and technical implementation of the Personal Ledger Android mobile application.

---

## 1. Executive Summary

The **Personal Ledger Android App** is a cross-platform (Flutter/Dart), cloud-backed mobile application purpose-built for personal financial management. It provides expense tracking, income logging, receipt OCR scanning, recurring bill management, custom ledgers, and AI-powered spending analysis — all secured via Supabase's JWT-based authentication and database-enforced Row-Level Security.

### Technical Problem Solved
Financial apps either compromise on privacy (cloud-uploaded receipt images) or on intelligence (dumb spreadsheet-style inputs with no AI assistance). Personal Ledger bridges this gap by running **OCR entirely on-device** (no images leave the phone) while routing AI analysis through a **secure serverless Edge Function** (no API keys ever exposed to clients). All data is stored in a **Postgres backend with enforced row-level access control** — making unauthorized data access architecturally impossible, not just policy-dependent.

---

## 2. Core Features (V1.0.0)

- **Supabase Auth Integration**: JWT-based email/password authentication with persistent session management and auto-refresh.
- **Expense Tracking**: Create, edit, and delete expenses with date, amount, category dropdown (Food, Transport, Utilities, Health, Entertainment, Shopping, Education, Others), and notes. Monthly summaries and bar charts computed from live data.
- **Income Tracking**: Log income entries by source (Salary, Business, Investments, Others) with date and notes. Net savings displayed dynamically.
- **Native OCR Receipt Scanning**: `google_mlkit_text_recognition` processes captured or gallery-selected receipt images entirely on-device. A custom `ReceiptParser` Dart engine extracts vendor, date, amount, and category using regex heuristics and keyword taxonomy.
- **AI Spending Advisor**: Calls a Supabase Edge Function (Deno TypeScript) which relays a structured prompt to Groq's `llama-3.3-70b-versatile` model. Returns a Markdown-rendered analysis panel with spending insights.
- **Custom Financial Ledgers**: User-created named ledgers with independently managed categories, separate expense tracking, income tracking, AI advisor, and CSV export.
- **Recurring Expenses Scheduler**: Tracks bills and subscriptions with configurable frequency, amount, and active/inactive status toggle.
- **PDF & CSV Export**: Generates reports from expense data using the `pdf` package and opens them with native file viewer integration.
- **Retro Editorial Theme**: Warm parchment colour palette, serif typography (`Playfair Display` headings, `Lora` body), and custom `fl_chart` canvas-drawn bar charts — a premium UI aesthetic unlike standard Material apps.

---

## 3. High-Level System Architecture

The application follows a clean **MVVM (Model-View-ViewModel)** architecture with a service layer for external integrations:

```mermaid
graph TD
    style UI fill:#fdf6ec,stroke:#c9a96e,stroke-width:2px;
    style VM fill:#faf5ff,stroke:#a855f7,stroke-width:2px;
    style Data fill:#f0fdf4,stroke:#22c55e,stroke-width:2px;
    style External fill:#eff6ff,stroke:#3b82f6,stroke-width:2px;

    subgraph UI_Layer [UI Layer]
        UI["Views — ExpensesTab, IncomeTab, LedgerDetailView, RecurringTab, AnalysisView"]
    end

    subgraph Logic_Layer [Logic / ViewModel Layer]
        VM["ViewModels — AuthViewModel, ExpensesViewModel, CustomLedgerDetailViewModel"]
    end

    subgraph Data_Layer [Data Layer]
        Data["SupabaseService — CRUD Operations, Edge Function Invoker"]
        OCR["OCRService — image_picker + google_mlkit_text_recognition"]
        Parser["ReceiptParser — Vendor / Date / Amount / Category Engine"]
    end

    subgraph External [External Services]
        Supabase["Supabase (Postgres + Auth + Edge Functions)"]
        Groq["Groq API — llama-3.3-70b-versatile"]
    end

    UI -->|User Actions| VM
    VM -->|State Updates via ChangeNotifier| UI
    VM -->|Data Requests| Data
    Data -->|Authenticated Queries| Supabase
    Data -->|SDK Function Invoke| Supabase
    Supabase -->|Secure Server-Side Call| Groq
    UI -->|Trigger Scan| OCR
    OCR -->|Raw OCR Text| Parser
    Parser -->|ParsedReceipt| UI
```

---

## 4. System Flow Diagrams

### Flow A: Receipt OCR Scanning & Form Auto-Fill

This diagram details the on-device receipt scanning pipeline from image capture to expense form population:

```mermaid
sequenceDiagram
    autonumber
    actor User
    participant UI as ExpensesTab / LedgerDetailView
    participant OCR as OCRService
    participant MLKit as ML Kit Text Recognizer
    participant Parser as ReceiptParser
    participant Form as Expense Form Controllers

    User->>UI: Taps "Scan Receipt" button
    UI->>UI: Show bottom sheet — Camera or Gallery
    User->>UI: Selects Camera or Gallery option
    UI->>OCR: pickAndParseReceipt(fromCamera)
    OCR->>OCR: ImagePicker.pickImage(source)
    OCR->>OCR: InputImage.fromFilePath(imagePath)
    OCR->>MLKit: textRecognizer.processImage(inputImage)
    MLKit-->>OCR: RecognizedText (raw blocks)
    OCR->>OCR: Concatenate all text blocks into rawOcrText
    OCR->>Parser: ReceiptParser().parseReceipt(rawOcrText)
    Parser->>Parser: _extractVendor() — regex word-boundary match against known vendors, fallback to first clean line
    Parser->>Parser: _extractDate() — match "15 Aug, 2026" / "2026-08-15" patterns, normalize to YYYY-MM-DD
    Parser->>Parser: _extractTotalAmount() — scan "Grand Total", "Paid", "Bill Amount" keyword rows
    Parser->>Parser: _extractLineItems() — parse line-level descriptions
    Parser->>Parser: CategoryMatcher.suggestCategory(vendor, lineItems)
    Parser-->>OCR: ParsedReceipt(vendor, date, totalAmount, category, confidence)
    OCR-->>UI: ParsedReceipt returned
    UI->>Form: _expDescController.text = vendor
    UI->>Form: _expDateController.text = date (formatted)
    UI->>Form: _expAmountController.text = totalAmount
    UI->>Form: _selectedCategory = matched category
    UI->>User: Show SnackBar — "Receipt parsed: Lassi Story, ₹390.00"
```

---

### Flow B: AI Spending Advisor — Secure Edge Function Invocation

This diagram shows how the AI analysis request flows securely through the Supabase SDK, bypassing raw HTTP and ensuring API keys remain server-side:

```mermaid
sequenceDiagram
    autonumber
    actor User
    participant UI as AnalysisView
    participant VM as AuthViewModel
    participant Service as SupabaseService
    participant SDK as Supabase Flutter SDK
    participant EdgeFn as Supabase Edge Function (Deno)
    participant Groq as Groq API (LLaMA)

    User->>UI: Selects period (Last Month / 3M / 6M) and taps "Analyze Spending"
    UI->>VM: analyzeSpending(period)
    VM->>Service: analyzeSpending(period: "1m")
    Service->>Service: Verify currentSession?.accessToken != null
    Service->>SDK: _client.functions.invoke("analyze-spending", body: {period})
    SDK->>SDK: Attach Authorization Bearer + apikey headers automatically
    SDK->>EdgeFn: POST /functions/v1/analyze-spending
    EdgeFn->>EdgeFn: Validate JWT — authenticate user
    EdgeFn->>EdgeFn: Query Supabase Postgres for user's expenses in period
    EdgeFn->>Groq: POST /chat/completions with structured spending prompt
    Groq-->>EdgeFn: LLM response — spending analysis narrative
    EdgeFn-->>SDK: { analysis: "..." } JSON response
    SDK-->>Service: FunctionResponse(status: 200, data: Map)
    Service-->>VM: Map<String, dynamic> analysisResult
    VM-->>UI: Update state — render Markdown analysis panel
    UI->>User: Display personalized AI spending advice
```

---

### Flow C: Custom Ledger — Category Management & Expense Entry

This diagram details the custom ledger expense creation flow including dynamic category management:

```mermaid
sequenceDiagram
    autonumber
    actor User
    participant UI as LedgerDetailView
    participant VM as CustomLedgerDetailViewModel
    participant Service as SupabaseService
    participant DB as Supabase Postgres (RLS)

    User->>UI: Opens a Custom Ledger
    UI->>VM: loadData(ledger.id)
    VM->>Service: getCategories(ledgerId)
    Service->>DB: SELECT * FROM ledger_categories WHERE ledger_id = ? AND user_id = auth.uid()
    DB-->>Service: List<LedgerCategory>
    Service-->>VM: categories list
    VM-->>UI: Render category dropdown + expense form

    opt User adds a new category
        User->>UI: Types new category name and taps "Add"
        UI->>VM: addCategory(name, ledgerId)
        VM->>Service: addCategory(name, ledgerId)
        Service->>DB: INSERT INTO ledger_categories (name, ledger_id, user_id)
        DB-->>Service: Inserted row
        VM->>VM: Reload categories list
        VM-->>UI: Dropdown refreshed with new category
    end

    User->>UI: Fills expense form (with optional Scan Receipt OCR)
    User->>UI: Taps "Add Expense"
    UI->>VM: addExpense(Expense with ledgerId)
    VM->>Service: addExpense(expense)
    Service->>DB: INSERT INTO expenses (amount, category, date, notes, ledger_id, user_id)
    DB-->>Service: Inserted (RLS verified user_id = auth.uid())
    VM->>VM: Reload expenses for this ledger
    VM-->>UI: Expense list and summary refreshed
```

---

## 5. Database Schema (Supabase Postgres)

All tables enforce Row-Level Security (`user_id = auth.uid()`).

| Table | Key Columns | Description |
|-------|-------------|-------------|
| `expenses` | `id, user_id, ledger_id, amount, category, expense_date, notes` | All expense records. `ledger_id` is NULL for personal expenses, populated for custom ledgers. |
| `income` | `id, user_id, ledger_id, amount, source, income_date, notes` | Income records per user or per ledger. |
| `ledgers` | `id, user_id, name, description, color, created_at` | User-created custom financial ledgers. |
| `ledger_categories` | `id, user_id, ledger_id, name` | Custom expense categories per ledger. |
| `recurring_expenses` | `id, user_id, name, amount, frequency, next_due_date, is_active` | Recurring subscription and bill entries. |
| `user_settings` | `id, user_id, alert_email, phone_number, sms_enabled` | Per-user notification preferences. |

---

## 6. Security & Data Privacy Design

```mermaid
graph LR
    A[Android App - Flutter] -->|JWT Token| B[Supabase Auth]
    A -->|Authenticated API Calls| C[Supabase Postgres]
    C -->|RLS Policy - auth.uid = user_id| D[User-Scoped Data Only]
    A -->|SDK Function Invoke| E[Supabase Edge Function]
    E -->|Server-Side GROQ_API_KEY| F[Groq LLaMA API]
    A -->|On-Device Only - No Network| G[ML Kit OCR]
    G -->|Receipt Text| A
```

- **JWT Authentication**: Every request is authenticated via a Supabase session JWT. Tokens are refreshed automatically and stored securely on-device.
- **Row-Level Security**: Postgres RLS policies enforce that every `SELECT`, `INSERT`, `UPDATE`, and `DELETE` operation is scoped to the authenticated `user_id`. Cross-user data access is physically impossible at the database layer.
- **Edge Function Security**: The Groq API key lives exclusively in Supabase Edge Function environment variables. It is never bundled in the app binary, never logged, and never transmitted to clients.
- **On-Device OCR**: Receipt images are processed by ML Kit's local text recognition model. No image is transmitted to any external server.

---

## 7. Future Enhancements & Roadmap

With the foundation of **V1.0.0** successfully established and verified, future iterations will implement:

1. **Push Notification Engine**: Supabase `pg_cron` + `pg_net` to trigger daily/weekly budget alerts via Firebase Cloud Messaging (FCM).
2. **Multi-Currency Support**: Currency selection in user settings with live exchange rate conversion (via open exchange rates API).
3. **Bank Statement Auto-Import**: Parse PDF or CSV bank statement exports to bulk-import transaction history.
4. **Spending Goals & Budget Caps**: User-defined category budget limits with progress rings and breach alerts.
5. **Biometric App Lock**: `local_auth` package integration for fingerprint / face unlock on app open.
6. **iOS App Store Launch**: Extend the Flutter codebase, configure Supabase deep link handlers, and publish on the Apple App Store.
7. **Offline Mode with Sync Queue**: Local SQLite cache with a conflict-resolving sync queue for zero-network usage.
