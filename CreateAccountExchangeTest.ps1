﻿#Import AD and Exchange
Import-Module ActiveDirectory
#$Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri http://exchange.domain.com.au/PowerShell/ -Authentication Kerberos 
#Import-PSSession $Session -AllowClobber

Function Input-Windows {
#Import VB
Add-Type -AssemblyName Microsoft.VisualBasic
$vb = [Microsoft.VisualBasic.Interaction]
#Variables
$samaccount_to_copy = $vb::inputbox("Enter SAMAccount Name to Copy")
$manageraccount = $vb::inputbox("Enter Manager SAMAccount Name")
$new_displayname = $vb::inputbox("Enter Display Name of new user")
$new_firstname = ($new_displayname.split(" ")[0])
$new_lastname = ($new_displayname.Substring($new_displayname.IndexOf(" ") + 1))
$new_name = $new_displayname
$CopyPath = $(try {(Get-AdUser $samaccount_to_copy).distinguishedName.Split(',', 2)[1]} catch {$null})
$ManagerPath = $(try {(Get-AdUser $manageraccount).distinguishedName.Split(',', 2)[1]} catch {$null})
$enable_user_after_creation = $true
$password_never_expires = $false
$cannot_change_password = $false
$ad_account_to_copy = $(try {Get-ADUser $samaccount_to_copy -Properties Description, Office, OfficePhone, StreetAddress, City, State, PostalCode, Country, Title, Company, Department, Manager, EmployeeID} catch {$null})
$ad_account_manager = $(try {Get-ADUser $manageraccount -Properties Office, OfficePhone, StreetAddress, City, State, PostalCode, Country, Company, Department} catch {$null})
    }

##### Generate Random Password from DinoPass # Credit to Chris Spencer
$web = New-Object Net.WebClient #Generates powershell web client
$web.Headers.Add("Cache-Control", "no-cache");
$PwdString = $web.DownloadString("http://www.dinopass.com/password/simple")
$PwdString = $PwdString.substring(0, 1).toUpper() + $PwdString.substring(1)
$Password = ConvertTo-SecureString -String $PwdString -AsPlainText -Force  

Function Checks {
#####Check accounts exist#####
$User = $(try {Get-ADUser $samaccount_to_copy -Properties * | Select Name} catch {$null})
 
If ($User -eq $Null) {
    Write-Host "User doesn't Exist in AD"
}
Else {
    Write-Host "User found in AD"
}
 
$Manager = $(try {Get-ADUser $manageraccount -Properties * | Select Name} catch {$null})
 
If ($Manager -eq $Null) {
    "Manager doesn't Exist in AD"
}
Else {
    "Manager found in AD"
    }

##### Check New User Exists #####

$NewUser = $(try {Get-ADUser $new_samaccountname -Properties * | Select Name} catch {$null})
 
If ($NewUser -eq $Null) {
    "Username doesn't exist, creating user"

}
Else {
    "Username already exists, choosing next letter in sequence"
    }
}

##### Generate Username - FirstInitialLastName
#function Generate-username($new_displayname)
#{
#    $count = 0
#
#    do
#   {
#        $count++
#        $new_samaccountname = "$($new_firstname.substring(0,$count))$new_lastname"
#    } until ( ! (Get-aduser -Filter {SamAccountName -eq $new_samaccountname} ) )
#
#    $new_samaccountname.ToLower()
#} 

##### Generate Username - FirstNameFirstInitialLastName #####
#function Generate-username($new_displayname)
#{
#    $count = 0
#
#    do
#    {
#        $count++
#        $new_samaccountname = "$new_firstname$($new_lastname.substring(0,$count))"
#    } until ( ! (Get-aduser -Filter {SamAccountName -eq $new_samaccountname} ) )
#
#    $new_samaccountname.ToLower()
#} 

### Otherwise FirstName.LastName
$new_samaccountname = ($new_displayname -replace " ", ".")

function CreateAccountWithMailbox {

Input-Windows

Checks

###Determine Home Directory Path##
$HomeDir = $(try {Get-ADUser $samaccount_to_copy -Properties HomeDirectory} catch {$null}) |

Select-Object -ExpandProperty HomeDirectory |
    Split-Path -Parent
"HomeDirectory will be $HomeDir"

$copy = if ($copy = $ad_account_to_copy ) {
    # return copy
    $copy
}
elseif ($copy = $ad_account_manager ) {
    # return copy
    $copy
}
else {
    Write-Host 'No manager or user specified'
    # cannot create user no copy returned
}

$path = if ($path = $CopyPath ) {
    $path
}
elseif ($path = $ManagerPath ) {
    $path
}
else {
    Write-Host 'No Path found'
}

if ($copy) {
    
    $Parameters = @{
        'SamAccountName' =  $new_samaccountname 
        'Instance' = $copy 
        'Name' = $new_name 
        'DisplayName' = $new_displayname 
        'GivenName' = $new_firstname 
        'Surname' = $new_lastname 
        'PasswordNeverExpires' = $password_never_expires 
        'CannotChangePassword' = $cannot_change_password 
        'EmailAddress' = ($new_firstname + '.' + $new_lastname + '@' + "mcauliffe-systems.com") 
        'Enabled' = $enable_user_after_creation 
        'UserPrincipalName' = ($new_samaccountname + '@' + "mcauliffe-systems.com") 
        'AccountPassword' = (ConvertTo-SecureString -AsPlainText $Password -Force) 
        'Path' = $path
    # other changes   
            }
New-ADUser @Parameters
}
else {
    Write-Host 'No account was specified.'
}

## Mirror all the groups of original account that is a member of or only copy Distribution Lists
#Option 1

If ($samaccount_to_copy) {
    $UserGroups = @()
    $UserGroups = (Get-ADUser -Identity $samaccount_to_copy -Properties MemberOf).MemberOf
    foreach ($Group in $UserGroups) {
        Add-ADGroupMember -Identity $Group -Members $new_samaccountname
    }
    (Get-ADUser -Identity $new_samaccountname -Properties MemberOf).MemberOf
} 
Else {
    
    ($manageraccount)
    Write-Host "Please Add Group Memberships Manually" 
    #
    #    ForEach ($Group in Get-DistributionGroup) 
    #{ 
    #   ForEach ($Member in Get-DistributionGroupMember -identity $Group.Name | Where { $_.Name –eq $manageraccount }) 
    #   { 
    #      $Group.name 
    #   } 
    #}
    #Add-DistributionGroupMember -Identity $Group.Name -Member $new_samaccountname -verbose
}

#Option 2 (Copies all groups filtered by ones only in specified OU (Distribution Groups)

#Get-ADPrincipalGroupMembership -Identity $manageraccount | 
#Where-Object {$_.DistinguishedName -match 'OU=Distribution Groups,OU=PRG,DC=iwf,DC=com,DC=au'}
#}

##### Confirm new account created

Get-ADUser $new_samaccountname

#### Set Home Directory Path #####
Set-ADUser -Identity $new_samaccountname -HomeDirectory $HomeDirectory -HomeDrive H

##### Clear and Set manager #####

Set-ADUser $new_samaccountname -Manager $null

Set-ADUser $new_samaccountname -Manager $manageraccount

### Set EmployeeID and Account Expirey if not set
#If ($empCode -notin ("TEMP","CONTRACTOR","NONPAYG") -AND $ad_account_to_copy -ne $NULL -or $ad_account_manager -ne $null) 
#{
#    $empCode = $vb::inputbox("Enter Employee ID")
#    Set-ADUser $new_samaccountname -EmployeeID $empCode 
#    Get-ADUser $new_samaccountname | Set-ADAccountExpiration -timespan 30.0:0
#} 
#Else 
#{
#"No Account Specified"
#}

### Enable Mailbox
#Enable-Mailbox $new_samaccountname

### Enable Lync (Add to AD Group)
#Add-ADGroupMember "enable-lync" -members $new_samaccountname

## Confirm Email Address
$EmailAddress = Get-ADUser $new_samaccountname -Properties mail | Select-Object -ExpandProperty mail

### Copy Mailbox Access ###
#$Mailboxes = Get-Mailbox -resultsize "Unlimited" | Get-MailboxPermission | where { ($_.AccessRights -eq "FullAccess") -and ($_.User -like "Domain\$samaccount_to_copy") -and ($_.IsInherited -eq $false) }
#ForEach ($mailbox in $mailboxes) {
#    $mailbox | Add-MailboxPermission -user Domain\$new_samaccountname -AccessRights "FullAccess"
#}

#### Confirm mailbox access granted ###
#Get-Mailbox -resultsize "Unlimited" | Get-MailboxPermission | where { ($_.AccessRights -eq "FullAccess") -and ($_.User -like "Domain\$new_samaccountname") -and ($_.IsInherited -eq $false) }
}
