# 00-promote-dc.ps1 - Manual DC promotion (if orchestrate fails)
# Run this via RDP on DC01 if simplified-orchestrate.ps1 Step 1 fails

Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
Install-ADDSForest -DomainName aum.local -SafeModeAdministratorPassword (ConvertTo-SecureString -AsPlainText -Force 'MichaelI#2026') -Force