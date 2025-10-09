# Repository Guidelines

## Project Structure & Module Organization
- SwiftUI app sources live in `PurpleM/`, with feature views in `Views/`, domain logic in `Services/` and `Models/`, and shared helpers in `Utils/`.
- Tests live in `PurpleMTests/` and `PurpleMUITests/`; keep fixtures next to the scenario they exercise.
- Serverless API entry points for chat and auth sit under `api/`. The production Vercel bundle resides in `vercel-backend/` (mirrors `api/`, ships with `vercel.json`).
- Supabase migrations and recovery scripts are in `supabase/`, while architectural context is collected in `docs/`.

## Build, Test, and Development Commands
- `open PurpleM.xcodeproj` opens the app in Xcode; build with the `PurpleM` scheme.
- `xcodebuild -project PurpleM.xcodeproj -scheme PurpleM -configuration Debug build` performs a reproducible local or CI build.
- `xcodebuild test -project PurpleM.xcodeproj -scheme PurpleM -destination 'platform=iOS Simulator,name=iPhone 15'` runs unit and UI suites.
- `cd vercel-backend && npm install && npx vercel dev` spins up the serverless backend locally.

## Coding Style & Naming Conventions
- Use Swift four-space indentation, `camelCase` members, and `PascalCase` types. Move long-running logic into `Services/` classes such as `EnhancedAIService.swift`.
- SwiftUI files should stay lean: let `Models/` define the data layer and `Utils/` host cross-cutting helpers.
- JavaScript handlers are ES modules with two-space indentation and `export default async function handler(req, res)` signatures.

## Testing Guidelines
- Write XCTests per feature change in `PurpleMTests`; script UI journeys in `PurpleMUITests` with descriptive selectors.
- Name tests `test<Scenario><Expectation>` and separate helpers with `// MARK:` blocks.
- For Supabase changes, attach a runnable snippet to `supabase/setup.md` or the impacted `supabase/functions/*` file so reviewers can replay the change.

## Commit & Pull Request Guidelines
- Follow the existing mix of Conventional Commits and emoji-prefixed fixes (`feat: …`, `🔧 修复…`). Start the subject with the emoji or scope keyword, then a concise summary.
- PRs should call out affected modules (`PurpleM/Services`, `api/chat-stream-enhanced.js`, `api/_shared/enhancedChatCore.js`, etc.), link doc or SQL updates, and attach simulator screenshots or curl traces when behavior changes.

## Supabase & Configuration Tips
- Keep credentials in local `.env` files or Vercel project settings; never commit secrets.
- When schema or policy updates land, update the matching script in `supabase/` and describe the migration path in the PR description.

永远用中文和我交流 
写好代码后直接推送到git，我在vercl部署后端直接进行测试，不需要在本地进行测试
