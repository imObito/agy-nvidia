Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
function Show-Main {
  $form = New-Object System.Windows.Forms.Form; $form.Text="agy-nvidia — Switch GUI"; $form.Size=New-Object System.Drawing.Size(500,300); $form.StartPosition="CenterScreen"
  $btn1 = New-Object System.Windows.Forms.Button; $btn1.Text="1. Check all models"; $btn1.Location=New-Object System.Drawing.Point(50,30); $btn1.Size=New-Object System.Drawing.Size(400,40); $btn1.Add_Click({ $form.Tag="check"; $form.Close() }); $form.Controls.Add($btn1)
  $btn2 = New-Object System.Windows.Forms.Button; $btn2.Text="2. Insert new NVIDIA API key"; $btn2.Location=New-Object System.Drawing.Point(50,80); $btn2.Size=New-Object System.Drawing.Size(400,40); $btn2.Add_Click({ $form.Tag="key"; $form.Close() }); $form.Controls.Add($btn2)
  $btn3 = New-Object System.Windows.Forms.Button; $btn3.Text="3. Model change"; $btn3.Location=New-Object System.Drawing.Point(50,130); $btn3.Size=New-Object System.Drawing.Size(400,40); $btn3.Add_Click({ $form.Tag="model"; $form.Close() }); $form.Controls.Add($btn3)
  [void]$form.ShowDialog(); return $form.Tag
}
$choice = Show-Main
if ($choice -eq "model") {
  $f2 = New-Object System.Windows.Forms.Form; $f2.Text="Choose group"; $f2.Size=New-Object System.Drawing.Size(500,300); $f2.StartPosition="CenterScreen"
  $lb = New-Object System.Windows.Forms.ListBox; $lb.Location=New-Object System.Drawing.Point(20,20); $lb.Size=New-Object System.Drawing.Size(440,180); $lb.Items.AddRange(@("gemini 3.8 flash (low/mid/high)","gemini 3.7 flash (low/mid/high)","gemini 3.6 flash (low/mid/high)","gemini 3.1 pro (low/mid/high/pro)")); $f2.Controls.Add($lb)
  $ok = New-Object System.Windows.Forms.Button; $ok.Text="Next"; $ok.Location=New-Object System.Drawing.Point(200,220); $ok.Size=New-Object System.Drawing.Size(100,30); $ok.Add_Click({ $f2.Tag=$lb.SelectedItem; $f2.Close() }); $f2.Controls.Add($ok)
  [void]$f2.ShowDialog(); $group=$f2.Tag
  if ($group) {
    $f3 = New-Object System.Windows.Forms.Form; $f3.Text="Choose free NVIDIA LLM"; $f3.Size=New-Object System.Drawing.Size(650,400); $f3.StartPosition="CenterScreen"
    $lb2 = New-Object System.Windows.Forms.ListBox; $lb2.Location=New-Object System.Drawing.Point(20,20); $lb2.Size=New-Object System.Drawing.Size(600,300); $lb2.Items.AddRange(@("deepseek-ai/deepseek-v4.1-flash","meta/llama-3.2-11b-vision-instruct","nvidia/nemotron-3-super-120b-a12b","nvidia/nemotron-3-ultra-550b-a55b","z-ai/glm-5.3-flash","moonshotai/kimi-k3")); $f3.Controls.Add($lb2)
    $ok2 = New-Object System.Windows.Forms.Button; $ok2.Text="Apply"; $ok2.Location=New-Object System.Drawing.Point(270,330); $ok2.Size=New-Object System.Drawing.Size(100,30); $ok2.Add_Click({ $f3.Tag=$lb2.SelectedItem; $f3.Close() }); $f3.Controls.Add($ok2)
    [void]$f3.ShowDialog(); $model=$f3.Tag
    if ($model) { [System.Windows.Forms.MessageBox]::Show("Would update $group -> $model`nRun: switch-model.bat $group $model","Done") }
  }
} elseif ($choice -eq "check") { [System.Windows.Forms.MessageBox]::Show("Check all models via: switch-model.sh list + curl health","Check") } elseif ($choice -eq "key") { $k=[Microsoft.VisualBasic.Interaction]::InputBox("Paste nvapi- key","API Key",""); if ($k) { [System.Windows.Forms.MessageBox]::Show("Would save key to .env","Key") } }
