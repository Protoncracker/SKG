# SecureKeyGenerator.bat

A standalone, zero-dependency Windows Batch script that generates a **deterministic 16-digit machine fingerprint** based on the system's Windows Product ID and SHA256 double-hashing via CertUtil.

Originally created as a **Proof of Concept** for studying client-side detection of unauthorized modifications in copyrighted software (anti-piracy, anti-cracking). The generated key can be used for machine identification, user flagging (bans, shadowbans), and integrity verification — all without requiring installation, external tools, or version management.

## How It Works

```
Windows Product ID (via systeminfo)
        |
        v
  [ Strip spaces ]
        |
        v
  SHA256 (certutil)  ──>  keyBaseHash
        |
        v
  SHA256 (certutil)  ──>  keyIngredientHash
        |
        v
  [ Extract numeric digits only from both hashes ]
        |
        v
  [ Interleave: positions 0,1,2,3 from Base
                 positions 0-2, 3-5, 6-8, 9-11 from Ingredient ]
        |
        v
  16-digit machine key
```

The key is **deterministic** — the same machine always produces the same output. The 1st, 5th, 9th, and 13th digits of the key are derived from `keyBaseHash`, while the remaining 12 digits come from `keyIngredientHash`. This interleaving means that specific digit positions can be used independently for different purposes (e.g., the Base-derived digits alone as a compact machine signature for flagging).

## Design Philosophy

This script is designed to be **standalone**. It requires no installation, no configuration files, no registry entries, and no version tracking. You drop it in, call it, and get a key. It uses only built-in Windows tools available from XP to 11.

However, standalone fingerprinting by itself is not enough for serious anti-tampering work. The script's own header recommends combining it with complementary techniques for production use. See [Complementary Techniques](#complementary-techniques-for-production-use) below.

## Usage

```batch
:: Run directly — prints the 16-digit key to stdout
SecureKeyGenerator.bat

:: Capture the output in another script
for /f %%k in ('SecureKeyGenerator.bat') do set "machineKey=%%k"

:: Check for errors via errorlevel
SecureKeyGenerator.bat
if %errorlevel% neq 0 echo Generation failed with code %errorlevel%
```

**Requirements:** Administrator privileges (for `systeminfo` and `certutil`).

## Output

A 16-digit numeric key:

```
4928173650284917
```

The output is fixed-format and non-configurable. The same machine will always produce the same key, unless the Windows Product ID changes (reinstallation, registry edit, etc.).

## Error Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Unsupported system language (not EN-US or PT-BR) |
| 2 | Insufficient permissions to run system commands |
| 3 | Failed to create temporary file |
| 4 | Failed to delete temporary file |
| 5 | CertUtil hash generation failed |
| 6 | Unexpected error during variable cleanup |

All errors output a generic message to stdout and return the specific code via `%errorlevel%`. On error, all variables and temporary files are cleaned up before exit to prevent data leakage.

## Supported Systems

- Windows XP through Windows 11 (expected)
- English (en-US) and Portuguese (pt-BR) system locales

## Dependencies

All built-in Windows tools — no external software required:

| Tool | Purpose |
|------|---------|
| `systeminfo` | Retrieves the Windows Product ID |
| `certutil` | Generates SHA256 hashes |
| `%TEMP%` | Temporary file storage (auto-cleaned on exit) |

## Known Limitations

### Single Entropy Source

The key relies exclusively on the Windows Product ID. This means:
- **Volume-licensed machines** (corporate environments) may share the same Product ID, producing identical keys across different physical machines.
- The Product ID can be modified via the Windows Registry (`HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProductId`), allowing a determined attacker to spoof or match another machine's fingerprint.
- Reinstalling Windows changes the Product ID, generating a different key for the same physical hardware.

For higher-assurance fingerprinting, consider combining with additional hardware identifiers (MAC address via `getmac`, disk serial via `wmic diskdrive get serialnumber`, BIOS UUID via `wmic csproduct get uuid`).

### CertUtil Error Detection

The `errorlevel` check after the `:hashfile` subroutine reflects the exit code of the `for /f` loop, not of `certutil` itself. If `certutil` fails but produces output (e.g., an error message on stderr while printing partial data to stdout), the hash variable may silently contain invalid data. A post-hoc validation step (checking hash length or digit count) would improve robustness.

### Language Fallback Scope

The Portuguese locale detection uses `findstr /C:"Identifica"` as a broad prefix match for the Product ID line in `systeminfo` output. While this works in practice (only the Product ID line contains this prefix), a more specific match like `"Identificação do produto"` would be stricter. Any system locale outside English and Portuguese will return error code 1.

---

# Anti-Tampering in Practice

The sections below go beyond the script itself. They document the broader context of machine fingerprinting as an anti-tampering tool: what complementary techniques exist, why no client-side protection is ever absolute, and what companies should realistically expect from anti-piracy engineering.

## Complementary Techniques for Production Use

SKG generates a machine fingerprint, but a fingerprint alone can be read, replicated, or bypassed. For serious anti-tampering, anti-cracking, or licensing systems, you should layer multiple techniques on top of it. The script header references three categories: **dead traces**, **timestamp verifications**, and **flag file exclusions**. Here's what these mean and how they work together.

### Dead Files (Dead Traces)

A dead file is an inert file with no functional purpose in the program — it exists solely as a **witness that the software was installed or ran at least once**. The program never reads from it or writes meaningful data to it. It just checks: _does this file exist?_

Because dead files serve no visible purpose, a cracker reviewing the program's behavior has no reason to reproduce them. If the program is pirated and redistributed, the dead file won't be present on the new machine, revealing that the installation didn't go through the legitimate process.

**Example:** An installer creates `%AppData%\YourApp\.cache_meta` alongside the actual program files. The file contains nothing useful (random bytes, or is empty). On launch, the program silently checks for its existence. If missing, the copy is flagged as potentially illegitimate. The file name and location should look mundane — something a cracker would ignore during analysis.

Dead files are most effective when:
- Their names blend in with legitimate application data
- Multiple dead files are scattered across different locations
- The check is not performed at startup (where crackers look first), but during a routine operation minutes or hours into execution

### Flag Files (Exclusion-Based Detection)

A flag file is the inverse of a dead file — it's a file that **should exist** during normal operation but would be **absent or deleted** if the program has been tampered with. The program plants the flag during a verified/trusted operation (e.g., right after successful activation or license validation). If a cracker patches out the validation step, the flag is never created. If they notice the flag and try to remove the validation while keeping the flag, the flag's content or timestamp won't match expectations.

**Example:** After successful online activation, the program writes a file containing a hash of `machineKey + activation timestamp`. On each launch, it re-derives the expected hash using the current machine key (from SKG) and checks it against the flag file. A cracker can't forge this file without knowing the hashing scheme, and deleting it triggers re-validation.

Flag files can also be used as **tripwires**: the program creates a flag at a specific moment, and if the flag is missing later, it means someone rolled back or tampered with the program state.

### Timestamp Verification

Comparing file creation/modification timestamps against expected values can reveal tampering. If a program was installed on date X, but its core files show a creation date of Y (e.g., because they were extracted from a cracked archive), the inconsistency signals a non-legitimate copy.

**Example:** The installer records the installation timestamp encrypted inside a file. On launch, the program compares this timestamp against the actual filesystem creation date of its own executable. A mismatch (beyond a small tolerance) suggests the files were copied or repackaged.

This also catches **clock manipulation**: if the user sets their system clock back to extend a trial period, comparing multiple independent timestamps (file creation, last NTFS journal entry, network time) can expose the discrepancy.

### Registry Breadcrumbs

Similar to dead files, but stored in the Windows Registry. Registry entries are harder to track during static analysis of a program's files, and crackers focused on patching executables often overlook registry artifacts entirely.

**Example:** The installer writes a value under `HKCU\Software\Classes\.yourext` that encodes a derivative of the machine key. The program checks this value periodically (not at startup). A pirated copy running on a different machine won't have this registry entry, and the expected value wouldn't match anyway since the machine key differs.

### Behavioral Fingerprinting

Instead of checking files or registry at a single point, the program monitors its own runtime behavior. This is the hardest technique for a cracker to defeat because there's no single checkpoint to patch out.

**Example:** The program uses the machine key from SKG to seed a deterministic sequence that dictates _when_ and _how_ integrity checks occur. On machine A, the check might happen 12 minutes after launch during a save operation. On machine B, it happens 7 minutes in during a menu transition. A cracker testing on their own machine can't predict when the check fires on other machines.

### How These Combine with SKG

SKG provides the **identity layer** — a unique, reproducible machine signature. The techniques above provide the **verification layer** — ways to confirm the software is running in an expected, untampered state. Together:

```
SKG (machine key)  ──>  "Who is this machine?"
Dead files         ──>  "Was this installed legitimately?"
Flag files         ──>  "Has the validation been bypassed?"
Timestamps         ──>  "Have the files been repackaged?"
Registry traces    ──>  "Is this the same environment that was activated?"
Behavioral checks  ──>  "Is the runtime integrity intact?"
```

No single technique is unbeatable. The strength is in layering — a cracker might defeat one or two, but each additional layer increases the effort required. SKG is the foundation: a portable, zero-dependency fingerprint that the other techniques can reference without needing network access or complex infrastructure.

## The Reality of Anti-Tampering

### What's on the user's machine belongs to the user

This is the fundamental truth that every anti-tampering discussion must start with. Once software is distributed to a client machine, the user has full physical and logical control over it. They can inspect every byte, intercept every system call, patch every conditional jump, and replay every network request. A sufficiently dedicated cracker **will** eventually bypass every client-side protection — this is not a possibility, it is a certainty. It's the same reason DRM on ebooks has never stopped a single determined person from obtaining a PDF.

Accepting this reality is not defeatism — it's engineering pragmatism. It informs how you should design your protections and, more importantly, what you should expect from them.

### The padlock principle

Anti-tampering tools are padlocks, not vaults.

A padlock on a door won't stop someone with bolt cutters or lockpicking skills. But it stops opportunists — people who would walk in if the door were simply open. The mere presence of the lock creates a threshold of effort. Most people won't bother crossing it, especially when the legitimate alternative (buying the software) is accessible and reasonably priced.

The goal of tools like SKG and its complementary techniques is not to make cracking impossible. It's to make cracking **annoying enough** that the effort isn't worth it for the average bad actor who would otherwise take every free opportunity available to them. You're filtering out the opportunists, not the specialists.

### Designing for inevitable defeat

Because every client-side check will eventually be defeated, at least one of your anti-tampering layers should **not block execution**. Instead, it should silently flag the anomaly and report it (if a network channel exists) or degrade functionality subtly enough that the cracker doesn't immediately realize which check they missed.

If every check is a hard block, the cracker has a clear binary signal: _the program runs or it doesn't_. That makes each check trivially identifiable — they patch, test, repeat until it launches. But if one check silently flags while the program continues running, the cracker may ship a "working" crack that is actually compromised, leaking machine fingerprints or disabling features on a delayed timer that only manifests after distribution.

This approach also protects legitimate users. Aggressive anti-tampering that hard-blocks on false positives (a corrupted dead file, a timestamp mismatch after a system restore, a registry entry wiped by a cleaner tool) punishes paying customers for circumstances outside their control. A silent flag avoids that collateral damage.

There is also a **forensic** reason for this approach, particularly relevant in commercial contexts. If a company is using a cracked copy of your software, a silent non-blocking check that leaves behind intact artifacts (dead files that were never created, flag files with mismatched hashes, registry entries that are absent or inconsistent) gives you a forensic trail. When your legal team or a hired expert inspects that company's machines, the absence or state of those artifacts serves as concrete, demonstrable evidence that the installation is illegitimate. If the check had hard-blocked and the company simply stopped using the software, you'd have nothing. A silent flag lets the unauthorized use continue — and document itself — until you're ready to act on it.

### When anti-tampering has real teeth

The strongest deterrent isn't client-side protection at all — it's **server-side consequence tied to real cost**.

If a program has an online component (multiplayer, cloud saves, account-linked content, API access), the machine fingerprint from SKG becomes genuinely powerful. Not because it can't be spoofed, but because spoofing it has a **cost**:

- **Account termination**: If a flagged fingerprint leads to a banned account, and that account held purchased content, the cracker loses real money. Creating a new account means repurchasing. Combined with multiple fingerprinting vectors (machine key, hardware IDs, behavioral patterns), evading the ban becomes progressively more expensive.
- **Feature revocation**: A hybrid local/cloud program can silently downgrade a flagged installation — disabling cloud sync, removing access to online content, throttling API calls. The cracked copy "works" but delivers a degraded experience that legitimate users don't suffer.
- **Reputation tagging**: In multiplayer or community contexts, flagged accounts can be silently moved to low-priority pools, matchmaking queues, or shadow-restricted environments. The user isn't told they've been flagged — they just notice the experience getting worse.

These approaches work because they tie the consequence to something the cracker can't just patch away on their local machine. The server decides. The client can be fully compromised and it doesn't matter — the punishment lives where the cracker has no control.

Crucially, this also constrains both **supply and demand** for cracked versions. On the supply side, crackers invest time and skill into producing a working crack — but if the result gets accounts banned, content revoked, or machines flagged, the crack's reputation collapses. Nobody wants to distribute a crack that gets its users punished, and a cracker doesn't want to burn their own accounts and money testing against a system that might flag them at any moment. On the demand side, users considering a cracked copy face a risk calculus that goes beyond "will it work?": they risk losing existing legitimate purchases tied to their account, being locked out of buying legitimate copies in the future (hardware-flagged storefronts), and having to source the crack from unverified, potentially malware-laden channels. When both the person producing the crack and the person using it face a lose-lose scenario — wasted effort and real financial loss — the psychological and economic deterrent becomes far more powerful than any technological barrier. You don't need an unbreakable lock if picking it costs more than the key.

### The cost of enforcement

That said, running a persistent anti-cracking infrastructure costs money. Servers, monitoring, analytics, ban-wave coordination, customer support for false positives — it's an ongoing operational expense. Companies should honestly assess whether this cost is justified by the actual revenue lost to piracy, rather than the imagined revenue lost.

The uncomfortable truth is: most people who pirate a product were never going to buy it at the asking price. They pirate because the barrier to pirating is lower than the barrier to purchasing — whether that barrier is price, regional availability, payment friction, or simply habit. Converting pirates into customers is more effectively done by lowering the legitimate barrier than by raising the piracy barrier.

A program that is reasonably priced, easy to purchase, and pleasant to use will naturally suffer less piracy than one that is overpriced, region-locked, and hostile to its own customers with intrusive DRM. This is not idealism — it's observable market behavior.

### A note to companies considering anti-piracy solutions

Before investing in anti-tampering engineering, perform an honest self-assessment:

- **Is your product priced fairly for its value and target market?** Overpriced software gets pirated more. This is not a moral judgment — it's supply and demand.
- **Is your product accessible?** Regional restrictions, payment method limitations, and platform exclusivity push users toward piracy out of necessity, not malice.
- **Is your product user-friendly?** If the pirated version offers a better user experience than the legitimate one (no launcher, no always-online requirement, no unskippable telemetry), you have a product problem, not a piracy problem.
- **What is your long-term reputation worth?** Aggressive DRM that punishes paying customers (always-online requirements that fail, hardware-locked activations that break on upgrades, rootkit-level anti-cheat) generates lasting resentment. The short-term revenue protected is often dwarfed by the long-term brand damage.

Steam, as of the time of writing this README (2026), remains one of the clearest examples of this principle in practice. By making the legitimate experience convenient, affordable (regional pricing, frequent sales), and feature-rich (achievements, cloud saves, community, workshop), it converted an industry that was hemorrhaging to piracy into one where most users actively prefer the paid platform. Steam didn't win by building better locks — it won by making the door more inviting than the window.

The best anti-piracy strategy is a product worth paying for, sold at a price people can afford, through a process that respects their time. Anti-tampering tools like SKG have their place — they're the padlock on the door. But if the door leads to a room nobody wants to be in, no lock in the world will matter.

---

## Project Status

**Archived.** Version 1.0.0.0 (FINAL) — no further development planned. This script serves as a finished reference and portfolio piece.

## License

This project is licensed under the [GNU General Public License v3.0](LICENSE) (or go to https://www.gnu.org/licenses/gpl-3.0.html)

## Author

**protoncracker** — June 2023 ~ February 2026
