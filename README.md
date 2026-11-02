# Trust WizardStone as a Publisher

On windows EXEs that require UAC and do not have a paid security publisher give a warning screen.  
To prevent this, this script installs a certificate basically saying 'I trust WizardStone'.

>[!CAUTION]
>Only do this if you know the security impications and are willing to make EXEs that may be unsafe look perfectly normal - like ones officially issued by Microsoft.

## Methord 1: via Scripting
In this methord you will install the certificate using powershell and installer scripts.
### Step 1: Open Powershell
You can open powershell however you chose but you can also using the enclosed methord.
>[!NOTE]
>If you want to install the certificate forall users you will need to open the shell as admin

1.Press `win` + `r` and type `powershell` and then press `enter` (or `ctrl` + `shift` + `enter` for admin)  
2. In the CLI type
```
irm https://wizardstone.github.io/trust/install.ps1
```
and press enter.  
Select wanted option or escape to cancel
