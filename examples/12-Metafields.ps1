<#
.SYNOPSIS
    Inspect field configuration ("metafields") for each model.
.DESCRIPTION
    The metafields/ endpoint is read-only. It returns field_settings (the
    school's configured fields) and default_field_settings (platform defaults),
    each keyed by model. Every field has a `label` plus `enabled` / `mandatory`
    maps keyed by scope:

        enr   = enrolment form      evt   = event booking
        eoi   = GPA / EOI form      cust  = custom form
        enq   = enquiry form        admin = admin view (enabled only)
#>

#Requires -Version 7.0
Import-Module ./src/EnrolHQ.PowerShell

Connect-EnrolHQ -Instance 'demo.enrolhq.com.au' -ApiToken 'your-token'

$fieldSettings = Get-EnrolHQMetafields -Section FieldSettings

# Each model is a property on the returned object.
$models = $fieldSettings.PSObject.Properties.Name
Write-Host "Configured models: $($models.Count)"
Write-Host "  $(( $models | Sort-Object ) -join ', ')"

# Inspect a single model's fields. `_meta` is metadata, not a field — skip it.
$model = if ($models -contains 'parent') { 'parent' } else { $models[0] }
Write-Host "`nFields on '$model':"
foreach ($field in $fieldSettings.$model.PSObject.Properties) {
    if ($field.Name -eq '_meta') { continue }
    $cfg = $field.Value
    $label = if ($cfg.label) { $cfg.label } else { $field.Name }
    Write-Host ("  {0,-30} enrolment: enabled={1} mandatory={2}" -f `
        $label, $cfg.enabled.enr, $cfg.mandatory.enr)
}

# Find every field that is mandatory on the enrolment form, across all models.
Write-Host "`nMandatory on the enrolment form:"
foreach ($modelProp in $fieldSettings.PSObject.Properties) {
    foreach ($field in $modelProp.Value.PSObject.Properties) {
        if ($field.Name -eq '_meta') { continue }
        if ($field.Value.mandatory.enr) {
            Write-Host "  $($modelProp.Name).$($field.Name) ($($field.Value.label))"
        }
    }
}

Disconnect-EnrolHQ
