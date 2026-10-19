# PET CT SHEET migration

Source package: NuclearScan_Server300_V2_4_AnyPath.zip (local artifact, not yet uploaded to this repository).

Required migration:
1. Commit all application source files including index.html and PowerShell scripts.
2. Never commit Data/bookings.json, settings containing personal data, Backups, or Logs.
3. Verify Windows startup at http://127.0.0.1:300/api/health.
4. Verify bookings persist after moving the application directory.
5. Verify print alignment and 25 pt bold default font.
6. Verify daily backups contain both bookings and print settings.
7. Test autostart after Windows login and after changing folder location.

IMPORTANT: Repository currently does not contain the complete application. Do not publish a release or claim the Windows server is fixed until tests pass.
