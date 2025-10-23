# scripts-and-things
Various scripts and things I made or use for work

# powershell/support_tools
All scripts can be run directly from the Scripts directory, but I created a .cmd file wrapper for each of them at the root level of support_tools so that you can just double click on them from the File Manager. Any file that contains admin will need administrator escalation.

All of the wrapper files are copies of each other, they each check to see if the name of itself contains admin or not, and then calls a run_script.ps1 file in the scriptsdir, passes it's own name and if admin is needed.  Run_script.ps1 in term runs the matching ps1 script. This was done this way to prevent some sort of nuesance and I don't remember what. lol
