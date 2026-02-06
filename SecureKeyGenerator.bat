@echo off
@chcp 1252>nul
setlocal enabledelayedexpansion
:: BATCH SCRIPT INFORMATION
:: Author: protoncracker
:: Name: SecureKeyGenerator.bat
:: Date: 14/06/2023
:: Version: 1.0.0.0 (FINAL)
:: System Compatibility: Windows XP to Windows 11 (Expected)
::
:: Description: This standalone batch script generates a unique value using a
:: randomized order for various client-side user-related treatments. It 
:: utilizes the ID from the Windows Installation for uniqueness. For flagging
:: purposes (e.g., banning, shadowbanning, cracker identification), you can
:: utilize the 1st, 5th, 9th, and 13th digits of the generated key.
::
:: This script was originally generated to study and test the detection of
:: unauthorized modifications in Copyrighted programs (pirating). It is a PoC.
:: 
:: Recommendation: For enhanced security, it is recommended to complement the
:: generated key with additional measures. Consider utilizing dead traces,
:: timestamps verifications, and/or exclusions (e.g., by deleting flag files)
:: in your overall implementation.
:: 
:: Output (Solo): The script outputs a 4x4 (16) digit key. The output is
:: fixed and non-configurable, ensuring consistent formatting.
::
:: Dependencies: 
::   - CertUtil (built-in Windows tool) for generating the hash of the system
:: information.
::   - systeminfo (built-in command) for retrieving the Windows Installation
:: ID.
::   - %TEMP% (built-in folder) for temporary output file storage.
::
:: Supported Languages:
::   - English (en-US)
::   - Portuguese (pt-BR)



:: Define temporary file path for storing systeminfo output and generate hashes
:regen
set temp_file=%TEMP%\%random%%random%%random%.tmp

:: Ensure temporary file is unique before starting the script
if exist "%temp_file%" goto :regen

:: Fetch and store the system information to the temp_file for later parsing
systeminfo > "%temp_file%"
if %errorlevel% NEQ 0 set "INTERNAL_ERROR_CODE=2"&goto :ERROR
if not exist "%temp_file%" set "INTERNAL_ERROR_CODE=3"&goto :ERROR

:: Initialize or clear variables before assignment
set "systemProductID="
set "keyIngredientHash="
set "keyBaseHash="

:: Extract the product ID from the system information
for /f "delims=: tokens=2" %%a in ('type "%temp_file%" ^| findstr /C:"Product ID"') do set "systemProductID=%%a"

:: Consider language differences: If Product ID not found, search for Identifica (Portuguese)
if not defined systemProductID for /f "delims=: tokens=2" %%a in ('type "%temp_file%" ^| findstr /C:"Identifica"') do set "systemProductID=%%a"

:: If still not found, print error message and set "INTERNAL_ERROR_CODE=1"&goto :ERROR
if not defined systemProductID (echo ERROR: LANGUAGE NOT SUPPORTED!?&set "INTERNAL_ERROR_CODE=1"&goto :ERROR)

:: Write the product ID to the temp file, removing any spaces for later hash generation
set /p "=!systemProductID: =!"<nul>"%temp_file%"

:: Hash the file using CertUtil to generate keyBaseHash
call :hashfile keyBaseHash

:: Append the keyBaseHash rewriting temp_file for the next hash generation
set /p "=!keyBaseHash: =!"<nul>"%temp_file%"

:: Generate keyIngredientHash from the updated temp_file
call :hashfile keyIngredientHash

:: Delete the temporary file after use
if exist "%temp_file%" del /q /f "%temp_file%" >nul
if %errorlevel% NEQ 0 set "INTERNAL_ERROR_CODE=4"&goto :ERROR

:: Remove any non-digit characters from the hashes for key generation (optional, can be edited)
call :removedigits keyBaseHash clean_keyBaseHash
call :removedigits keyIngredientHash clean_keyIngredientHash

:: Generate key using parts of the cleaned hashes (probably can be prettyfied to better reading)
set "key=!clean_keyBaseHash:~0,1!!clean_keyIngredientHash:~0,3!!clean_keyBaseHash:~1,1!!clean_keyIngredientHash:~3,3!!clean_keyBaseHash:~2,1!!clean_keyIngredientHash:~6,3!!clean_keyBaseHash:~3,1!!clean_keyIngredientHash:~9,3!"
echo %key%
endlocal
exit /b

:hashfile       Hashes the content of the temp_file using SHA256 algorithm and stores in passed variable
setlocal
set "hash="
for /f "skip=1 delims=" %%i in ('certutil -hashfile "%temp_file%" SHA256') do (
    if not defined hash set "hash=%%i"
)
if %errorlevel% neq 0 set "INTERNAL_ERROR_CODE=5"&goto :ERROR
endlocal & set "%1=%hash%"
exit /b

:removedigits   Removes all non-digit characters from specified variable and stores in a new specified variable
setlocal enabledelayedexpansion
set "clean_str="
for /l %%j in (0, 1, 63) do (
    set "current=!%1:~%%j,1!"
    for /l %%n in (0, 1, 9) do (
        if !current! EQU %%n (
            set "clean_str=!clean_str!!current!"
        )
    )
)
if %errorlevel% neq 0 set "INTERNAL_ERROR_CODE=6"&goto :ERROR
endlocal & set "%2=%clean_str%"
exit /b

:ERROR      Print error message and clean up variables and temporary file for privacy and security purposes
echo ERROR: Not enough permissions. Check the error code (errorlevel) and manual.
if exist "%temp_file%" del /q /f "%temp_file%"
set temp_file=
set systemProductID=
set keyBaseHash=
set clean_keyBaseHash=
set keyIngredientHash=
set clean_keyIngredientHash=
set key=
set hash=
set clean_str=
endlocal
exit /b %INTERNAL_ERROR_CODE%
:: 2: Not enough permissions to execute needed commands.
:: 3: Not enough permissions to create temporary file.
:: 4: Not enough permissions to delete created temporary file.
:: 5: Error in CertUtil utility.
:: 6: Unknown error during the cleaning of variables.