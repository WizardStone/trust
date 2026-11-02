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

Press `win` + `r` and type `powershell` and then press `enter` (or `ctrl` + `shift` + `enter` for admin)  

### Step 2: Execute the Script
In the CLI type
```
irm https://wizardstone.github.io/trust/install.ps1
```
and press enter. 

### Step 3: Select Option and Install
Select wanted option using arrow keys and press enter. To cancel press escape.

## Methord 2: via GUI
You can install the certificate via the graphical user interface if you would rather, but this requires downloading the file from the internet.  
### Step 1: Download Certificate
You can download the certificate from this GitHub repository however you choose.  Here is a suggesed like which will do it automatically: [install certificate](https://cdn.jsdelivr.net/gh/WizardStone/trust@main/WizardStone-CodeSigning.cer)
>[!CAUTION]
>That link uses jsdeliver a 3rd part CDN

### Step 2: Open and Install
Navigate to the file explorer (`win` + `e`) and locate the certificate file you downloaded.  
`Right Click` the file and press `install certificate`
