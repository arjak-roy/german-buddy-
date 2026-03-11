lib/
├── core/               # Shared logic used everywhere
│   ├── constants/      # App colors, strings, API endpoints
│   ├── errors/         # Custom exceptions for AI/Network
│   ├── theme/          # Global styles (Dark/Light mode)
│   ├── utils/          # Formatting, validators, voice helpers
│   └── widgets/        # Reusable UI components (Buttons, Loaders)
│
├── features/           # Modular components of BorderPlus
│   ├── auth/           # Login/Signup logic
│   ├── nurse_chat/     # The RAG-powered Chat & Voice simulation
│   │   ├── data/       # Models, DTOs, and API calls for this feature
│   │   ├── domain/     # Pure business logic & entities (no Flutter imports)
│   │   └── presentation/ # Screens, Widgets, and State Management (Providers)
│   └── dashboard/      # Progress tracking & stats
│
├── main.dart           # App entry point
└── app.dart            # Main MaterialApp configuration