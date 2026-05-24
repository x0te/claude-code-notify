#requires -version 5
[CmdletBinding()]
param()

Add-Type -AssemblyName PresentationCore, PresentationFramework, WindowsBase, System.Drawing, System.Windows.Forms

# === Paths ===
$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigPath = Join-Path $ScriptDir 'notify-config.json'
$IconsDir   = Join-Path $ScriptDir 'icons'
$NotifyPs1  = Join-Path $ScriptDir 'notify.ps1'
if (-not (Test-Path $IconsDir)) { New-Item -ItemType Directory -Path $IconsDir -Force | Out-Null }

# === Emoji 카탈로그 ===
$EmojiCatalog = [ordered]@{
    '🌟 별/반짝'    = @('⭐','🌟','✨','💫','☀️','🌙','🌞','🔮','💎','🌠','⚡')
    '🐱 동물'       = @('🐱','🐶','🐰','🦊','🐻','🐼','🐹','🐧','🦄','🦋','🐝','🐢','🐳','🦁','🐯','🐨','🐮','🐸','🐙','🐬')
    '💕 하트'       = @('❤️','🧡','💛','💚','💙','💜','🤍','🩷','💕','💖','💗','💞','💝','💘','💟')
    '🌸 자연'       = @('🌸','🌺','🌷','🌻','🌹','🌼','🍀','🌿','🌱','🌈','☁️','🌊','🌍','🌳','🍃')
    '🍓 음식'       = @('🍓','🍒','🍑','🍎','🍇','🍰','🍪','🧁','🍯','🍵','☕','🍩','🍙','🍡','🥨')
    '🎵 음악'       = @('🎵','🎶','🎼','🔔','🥁','🎺','🎻','🎤','🎧','🪕')
    '🎀 사물'       = @('🎀','🎈','🎁','💡','📅','📆','⏰','✅','🎯','📌','📍','📚','✏️','🪄','🖋')
    '🤖 클로드/특수' = @('✱','✦','✧','◈','◇','◆','🤖','💜','🌟','✴️')
}

# === 멜로디 프리셋 ===
$MelodyPresets = [ordered]@{
    # --- Cute (sine wave) ---
    triumph       = @{ Wave='sine';     Label='🎺 트라이엄프 (도-미-솔-도)';          Notes=@(@(523,90),@(659,90),@(784,90),@(1047,180)) }
    doorbell      = @{ Wave='sine';     Label='🛎 도어벨 (미-도-미-도)';              Notes=@(@(659,120),@(523,200),@(659,120),@(523,240)) }
    sparkle       = @{ Wave='sine';     Label='✨ 반짝 (솔-시-레-솔)';                Notes=@(@(784,80),@(988,80),@(1175,80),@(1568,180)) }
    chime         = @{ Wave='sine';     Label='🔔 차임 (라-도-미)';                   Notes=@(@(880,120),@(1047,120),@(1319,200)) }
    ping          = @{ Wave='sine';     Label='🟢 핑 (미-솔)';                        Notes=@(@(659,100),@(784,200)) }
    twinkle       = @{ Wave='sine';     Label='🌟 반짝반짝 작은별';                   Notes=@(@(523,180),@(523,180),@(784,180),@(784,180)) }
    powerup       = @{ Wave='sine';     Label='🆙 파워업';                             Notes=@(@(523,70),@(659,70),@(784,70),@(1047,70),@(1319,180)) }
    descend       = @{ Wave='sine';     Label='⬇️ 하강 (솔-미-도)';                   Notes=@(@(784,120),@(659,120),@(523,240)) }
    single        = @{ Wave='sine';     Label='🔘 단일음';                             Notes=@(@(800,300)) }
    soft          = @{ Wave='sine';     Label='☁️ 부드러움';                           Notes=@(@(440,80),@(587,180)) }
    royal         = @{ Wave='sine';     Label='👑 팡파레';                             Notes=@(@(523,150),@(659,150),@(784,150),@(659,150),@(1047,300)) }
    cute          = @{ Wave='sine';     Label='🍭 귀여움';                             Notes=@(@(880,80),@(1175,80),@(880,80),@(1318,160)) }

    # --- 8-bit Classic Game SFX (chiptune 합성) ---
    mario_coin    = @{ Wave='square';   Label='🪙 Mario · 코인';                       Notes=@(@(988,80),@(1319,420)) }
    mario_1up     = @{ Wave='square';   Label='1️⃣ Mario · 1-Up';                      Notes=@(@(659,125),@(784,125),@(1319,125),@(1047,125),@(1175,125),@(1568,280)) }
    mario_powerup = @{ Wave='square';   Label='🍄 Mario · 파워업';                     Notes=@(@(523,60),@(784,80),@(523,60),@(1047,80),@(659,60),@(1319,80),@(880,100),@(1568,200)) }
    mario_jump    = @{ Wave='square';   Label='🦘 Mario · 점프';                       Notes=@(@(523,40),@(659,40),@(784,40),@(988,40),@(1175,80)) }
    mario_pipe    = @{ Wave='square';   Label='🟫 Mario · 파이프';                     Notes=@(@(988,50),@(784,50),@(659,50),@(523,50),@(330,150)) }
    mario_clear   = @{ Wave='square';   Label='🏁 Mario · 스테이지 클리어';            Notes=@(@(659,100),@(784,100),@(880,100),@(988,250)) }
    zelda_secret  = @{ Wave='triangle'; Label='🗝 Zelda · 비밀 발견';                  Notes=@(@(587,160),@(880,160),@(740,160),@(587,160),@(659,160),@(988,160),@(1175,160),@(1568,400)) }
    zelda_item    = @{ Wave='triangle'; Label='💎 Zelda · 아이템 획득';                Notes=@(@(587,120),@(880,120),@(1175,120),@(1568,400)) }
    ff_victory    = @{ Wave='square';   Label='🏆 FF · 승리 팡파레';                   Notes=@(@(659,150),@(659,150),@(659,150),@(659,400),@(523,200),@(587,200),@(659,200),@(587,200),@(659,500)) }
    sonic_ring    = @{ Wave='square';   Label='💍 Sonic · 링';                         Notes=@(@(1319,70),@(1976,200)) }
    pacman_eat    = @{ Wave='square';   Label='👻 Pac-Man · 도트';                     Notes=@(@(440,50),@(587,50),@(440,50),@(587,50),@(440,50),@(587,120)) }
    tetris_clear  = @{ Wave='square';   Label='🟦 Tetris · 라인 클리어';               Notes=@(@(880,60),@(988,60),@(1175,60),@(1319,250)) }
    pokemon_catch = @{ Wave='square';   Label='⚪ Pokemon · 포획';                     Notes=@(@(440,80),@(523,80),@(659,80),@(880,80),@(1047,300)) }
}

function Get-DefaultConfig {
    [ordered]@{
        version = 3
        enabled = $true
        app = [ordered]@{
            name  = 'Claude Code'
            icon  = '🤖'
            appId = 'ClaudeCode.Notify'
        }
        notification = [ordered]@{
            emoji        = '💬'
            text         = '잠깐 의견 좀 들려주세요~'
            melodyPreset = 'doorbell'
            customMelody = $null
            showSummary  = $true
            playSound    = $true
        }
        stop = [ordered]@{
            emoji        = '✨'
            text         = '끝났어요! 한번 봐주세요~'
            melodyPreset = 'triumph'
            customMelody = $null
            showSummary  = $true
            playSound    = $true
        }
    }
}

function Read-NotifyConfig {
    if (-not (Test-Path $ConfigPath)) { return Get-DefaultConfig }
    try {
        $obj = Get-Content -Raw -Encoding utf8 $ConfigPath | ConvertFrom-Json -ErrorAction Stop
        return $obj
    } catch { return Get-DefaultConfig }
}

function Save-NotifyConfig {
    param($Config)
    $json = $Config | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($ConfigPath, $json, [System.Text.UTF8Encoding]::new($false))
}

function ConvertTo-IcoFromEmoji {
    param(
        [Parameter(Mandatory)][string]$Emoji,
        [Parameter(Mandatory)][string]$OutPath,
        [int]$Size = 32
    )
    $tb = New-Object System.Windows.Controls.TextBlock
    $tb.Text = $Emoji
    $tb.FontFamily = New-Object System.Windows.Media.FontFamily 'Segoe UI Emoji'
    $tb.FontSize = $Size * 0.78
    $tb.TextAlignment = [System.Windows.TextAlignment]::Center
    $tb.Width = $Size; $tb.Height = $Size
    $tb.Background = [System.Windows.Media.Brushes]::Transparent
    $tb.Measure([System.Windows.Size]::new([double]$Size, [double]$Size))
    $tb.Arrange([System.Windows.Rect]::new(0, 0, [double]$Size, [double]$Size))
    $tb.UpdateLayout()
    $rtb = New-Object System.Windows.Media.Imaging.RenderTargetBitmap ($Size, $Size, 96.0, 96.0, [System.Windows.Media.PixelFormats]::Pbgra32)
    $rtb.Render($tb)
    $encoder = New-Object System.Windows.Media.Imaging.PngBitmapEncoder
    $encoder.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($rtb))
    $ms = New-Object System.IO.MemoryStream
    $encoder.Save($ms); $pngBytes = $ms.ToArray(); $ms.Dispose()
    $fs = [System.IO.File]::Open($OutPath, [System.IO.FileMode]::Create)
    $bw = New-Object System.IO.BinaryWriter $fs
    try {
        $bw.Write([uint16]0); $bw.Write([uint16]1); $bw.Write([uint16]1)
        $w = if ($Size -ge 256) { [byte]0 } else { [byte]$Size }
        $bw.Write($w); $bw.Write($w); $bw.Write([byte]0); $bw.Write([byte]0)
        $bw.Write([uint16]1); $bw.Write([uint16]32)
        $bw.Write([uint32]$pngBytes.Length); $bw.Write([uint32]22)
        $bw.Write($pngBytes)
    } finally { $bw.Close(); $fs.Close() }
}

function New-PreviewWav {
    param([array]$Notes, [string]$Wave = 'sine', [int]$SampleRate = 22050)
    $ampScale = switch ($Wave) { 'square' { 0.42 } 'triangle' { 0.95 } 'sawtooth' { 0.55 } default { 0.85 } }
    $amplitude = 32000 * $ampScale
    $ms = New-Object System.IO.MemoryStream
    $bw = New-Object System.IO.BinaryWriter $ms
    $total = 0; foreach ($n in $Notes) { $total += [int](($n[1]/1000.0)*$SampleRate) }
    $dataSize = $total * 2
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes('RIFF')); $bw.Write([uint32](36+$dataSize))
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes('WAVE'))
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes('fmt ')); $bw.Write([uint32]16)
    $bw.Write([uint16]1); $bw.Write([uint16]1); $bw.Write([uint32]$SampleRate); $bw.Write([uint32]($SampleRate*2))
    $bw.Write([uint16]2); $bw.Write([uint16]16); $bw.Write([System.Text.Encoding]::ASCII.GetBytes('data')); $bw.Write([uint32]$dataSize)
    foreach ($n in $Notes) {
        $freq=[double]$n[0]; $dur=[int](($n[1]/1000.0)*$SampleRate); $fade=[Math]::Max(40,[int]($dur*0.06))
        for ($i = 0; $i -lt $dur; $i++) {
            $env=1.0
            if ($i -lt $fade) { $env = $i/[double]$fade }
            elseif ($i -gt ($dur-$fade)) { $env = ($dur-$i)/[double]$fade }
            $t = $i/[double]$SampleRate; $phase = 2.0*[Math]::PI*$freq*$t
            switch ($Wave) {
                'sine'     { $val = [Math]::Sin($phase)*0.9 + [Math]::Sin($phase*3)*0.08 }
                'square'   { $val = if ([Math]::Sin($phase) -ge 0) { 0.9 } else { -0.9 } }
                'triangle' { $c = ($freq*$t)%1.0; if ($c -lt 0.5) { $val = ($c*4.0-1.0) } else { $val = (3.0-$c*4.0) } }
                'sawtooth' { $c = ($freq*$t)%1.0; $val = ($c*2.0-1.0) }
                default    { $val = [Math]::Sin($phase) }
            }
            $s = [int]($val * $amplitude * $env)
            if ($s -gt 32767) { $s = 32767 } elseif ($s -lt -32768) { $s = -32768 }
            $bw.Write([int16]$s)
        }
    }
    $bw.Flush(); $b = $ms.ToArray(); $ms.Dispose(); return $b
}

function Invoke-MelodyPreview {
    param([string]$PresetName)
    if (-not $MelodyPresets.Contains($PresetName)) { return }
    $preset = $MelodyPresets[$PresetName]
    try {
        $wav = New-PreviewWav -Notes $preset.Notes -Wave $preset.Wave
        $ms = New-Object System.IO.MemoryStream (,$wav)
        $sp = New-Object System.Media.SoundPlayer
        $sp.Stream = $ms
        $sp.Play()
    } catch {
        foreach ($n in $preset.Notes) { try { [console]::beep([int]$n[0], [int]$n[1]) } catch {} }
    }
}

# ============================================================
# Main XAML
# ============================================================
[xml]$mainXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Claude Code 알림 설정"
        Width="780" Height="820"
        Background="#F4F0EA"
        WindowStartupLocation="CenterScreen"
        ResizeMode="CanMinimize"
        FontFamily="Segoe UI"
        Foreground="#2F2620">
    <Window.Resources>
        <SolidColorBrush x:Key="CardBg"      Color="#FFFBF5"/>
        <SolidColorBrush x:Key="SubCardBg"   Color="#F0E8DC"/>
        <SolidColorBrush x:Key="Accent"      Color="#D97757"/>
        <SolidColorBrush x:Key="AccentHover" Color="#E08770"/>
        <SolidColorBrush x:Key="Subtle"      Color="#8C7E70"/>

        <Style x:Key="FlatBtn" TargetType="Button">
            <Setter Property="Background" Value="#EDE3D4"/>
            <Setter Property="Foreground" Value="#2F2620"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Padding" Value="14,9"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="b" Background="{TemplateBinding Background}" CornerRadius="10" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="b" Property="Background" Value="#E0D5C8"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="PrimaryBtn" TargetType="Button" BasedOn="{StaticResource FlatBtn}">
            <Setter Property="Background" Value="#D97757"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="b" Background="{TemplateBinding Background}" CornerRadius="10" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="b" Property="Background" Value="#E08770"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="IconBtn" TargetType="Button">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="b" Background="{TemplateBinding Background}" CornerRadius="18" Padding="6">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="b" Property="Background" Value="#E0D5C8"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style TargetType="TextBox">
            <Setter Property="Background" Value="#FFFBF5"/>
            <Setter Property="Foreground" Value="#2F2620"/>
            <Setter Property="BorderBrush" Value="#E0D5C8"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="10,8"/>
            <Setter Property="CaretBrush" Value="#2F2620"/>
            <Setter Property="SelectionBrush" Value="#D97757"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="TextBox">
                        <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="8" Padding="{TemplateBinding Padding}">
                            <ScrollViewer x:Name="PART_ContentHost"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style TargetType="ComboBox">
            <Setter Property="Background" Value="#FFFBF5"/>
            <Setter Property="Foreground" Value="#2F2620"/>
            <Setter Property="BorderBrush" Value="#E0D5C8"/>
            <Setter Property="Padding" Value="8,6"/>
            <Setter Property="FontSize" Value="13"/>
        </Style>
        <Style TargetType="ComboBoxItem">
            <Setter Property="Background" Value="#2C2D38"/>
            <Setter Property="Foreground" Value="#F4F4F8"/>
            <Setter Property="Padding" Value="8,6"/>
        </Style>
        <Style TargetType="CheckBox">
            <Setter Property="Foreground" Value="#F5EFE6"/>
            <Setter Property="FontSize" Value="12"/>
        </Style>
    </Window.Resources>

    <Grid Margin="28">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- Header -->
        <Grid Grid.Row="0" Margin="0,0,0,12">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <StackPanel Grid.Column="0">
                <TextBlock Text="✱ Claude 알림 설정" FontSize="22" FontWeight="Bold" Foreground="#D97757"/>
                <TextBlock Text="아이콘 · 텍스트 · 멜로디 · 작업 요약을 마음대로 꾸며보세요" FontSize="12" Foreground="{StaticResource Subtle}" Margin="0,4,0,0"/>
            </StackPanel>
            <CheckBox x:Name="EnabledChk" Grid.Column="1" Content="알림 활성화" Foreground="#2F2620" VerticalAlignment="Center" FontSize="13"/>
        </Grid>

        <!-- App identity (이름 + 아이콘) -->
        <Border Grid.Row="1" Background="{StaticResource CardBg}" CornerRadius="12" Padding="16,12" Margin="0,0,0,16">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <TextBlock Grid.Column="0" Text="앱 이름" Foreground="{StaticResource Subtle}" FontSize="11" VerticalAlignment="Center" Margin="0,0,10,0"/>
                <TextBox x:Name="AppNameBox" Grid.Column="1" Width="180" MaxLength="40"/>
                <TextBlock Grid.Column="3" Text="아이콘" Foreground="{StaticResource Subtle}" FontSize="11" VerticalAlignment="Center" Margin="14,0,10,0"/>
                <Border Grid.Column="4" Background="{StaticResource SubCardBg}" CornerRadius="10" Width="44" Height="44">
                    <Button x:Name="AppIconBtn" Style="{StaticResource IconBtn}">
                        <TextBlock x:Name="AppIconText" FontSize="22" FontFamily="Segoe UI Emoji" Text="✱" Foreground="#D97757" FontWeight="Bold" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                    </Button>
                </Border>
            </Grid>
        </Border>

        <!-- Two cards -->
        <Grid Grid.Row="2">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="18"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>

            <!-- Notification -->
            <Border Grid.Column="0" Background="{StaticResource CardBg}" CornerRadius="16" Padding="22">
                <StackPanel>
                    <StackPanel Orientation="Horizontal" Margin="0,0,0,14">
                        <Border Background="#F4DDD0" CornerRadius="6" Padding="6,2">
                            <TextBlock Text="응답 필요" FontSize="11" Foreground="#B85A3A" FontWeight="SemiBold"/>
                        </Border>
                        <TextBlock Text="Notification" FontSize="11" Foreground="{StaticResource Subtle}" Margin="8,0,0,0" VerticalAlignment="Center"/>
                    </StackPanel>

                    <Border Background="{StaticResource SubCardBg}" CornerRadius="18" Width="92" Height="92" HorizontalAlignment="Center">
                        <Button x:Name="NotifIconBtn" Style="{StaticResource IconBtn}">
                            <TextBlock x:Name="NotifIconText" FontSize="46" FontFamily="Segoe UI Emoji" Text="💬" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Button>
                    </Border>
                    <TextBlock Text="클릭해서 아이콘 변경" FontSize="10" Foreground="{StaticResource Subtle}" HorizontalAlignment="Center" Margin="0,6,0,16"/>

                    <TextBlock Text="텍스트" Foreground="{StaticResource Subtle}" FontSize="11" Margin="0,0,0,6"/>
                    <TextBox x:Name="NotifText" MaxLength="40"/>

                    <TextBlock Text="멜로디" Foreground="{StaticResource Subtle}" FontSize="11" Margin="0,12,0,6"/>
                    <ComboBox x:Name="NotifMelody"/>

                    <CheckBox x:Name="NotifSummaryChk" Content="🔮 다음 작업 요약을 토스트에 포함" Foreground="#2F2620" Margin="0,14,0,0"/>
                    <CheckBox x:Name="NotifSoundChk" Content="🔊 알림 소리 재생" Foreground="#2F2620" Margin="0,8,0,0"/>

                    <Button x:Name="NotifTestBtn" Content="▶  미리듣기" Style="{StaticResource PrimaryBtn}" Margin="0,14,0,0"/>
                </StackPanel>
            </Border>

            <!-- Stop -->
            <Border Grid.Column="2" Background="{StaticResource CardBg}" CornerRadius="16" Padding="22">
                <StackPanel>
                    <StackPanel Orientation="Horizontal" Margin="0,0,0,14">
                        <Border Background="#E8DDD0" CornerRadius="6" Padding="6,2">
                            <TextBlock Text="작업 완료" FontSize="11" Foreground="#7A6249" FontWeight="SemiBold"/>
                        </Border>
                        <TextBlock Text="Stop" FontSize="11" Foreground="{StaticResource Subtle}" Margin="8,0,0,0" VerticalAlignment="Center"/>
                    </StackPanel>

                    <Border Background="{StaticResource SubCardBg}" CornerRadius="18" Width="92" Height="92" HorizontalAlignment="Center">
                        <Button x:Name="StopIconBtn" Style="{StaticResource IconBtn}">
                            <TextBlock x:Name="StopIconText" FontSize="46" FontFamily="Segoe UI Emoji" Text="✨" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Button>
                    </Border>
                    <TextBlock Text="클릭해서 아이콘 변경" FontSize="10" Foreground="{StaticResource Subtle}" HorizontalAlignment="Center" Margin="0,6,0,16"/>

                    <TextBlock Text="텍스트" Foreground="{StaticResource Subtle}" FontSize="11" Margin="0,0,0,6"/>
                    <TextBox x:Name="StopText" MaxLength="40"/>

                    <TextBlock Text="멜로디" Foreground="{StaticResource Subtle}" FontSize="11" Margin="0,12,0,6"/>
                    <ComboBox x:Name="StopMelody"/>

                    <CheckBox x:Name="StopSummaryChk" Content="📝 완료한 작업 요약을 토스트에 포함" Foreground="#2F2620" Margin="0,14,0,0"/>
                    <CheckBox x:Name="StopSoundChk" Content="🔊 알림 소리 재생" Foreground="#2F2620" Margin="0,8,0,0"/>

                    <Button x:Name="StopTestBtn" Content="▶  미리듣기" Style="{StaticResource PrimaryBtn}" Margin="0,14,0,0"/>
                </StackPanel>
            </Border>
        </Grid>

        <!-- Footer -->
        <Grid Grid.Row="3" Margin="0,20,0,0">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <TextBlock x:Name="StatusText" Grid.Column="0" Foreground="{StaticResource Subtle}" FontSize="12" VerticalAlignment="Center"/>
            <StackPanel Grid.Column="1" Orientation="Horizontal">
                <Button x:Name="TestBothBtn" Content="🔊 전체 미리듣기" Style="{StaticResource FlatBtn}" Margin="0,0,8,0"/>
                <Button x:Name="ResetBtn" Content="↺ 기본값" Style="{StaticResource FlatBtn}" Margin="0,0,8,0"/>
                <Button x:Name="SaveBtn" Content="💾 저장" Style="{StaticResource PrimaryBtn}"/>
            </StackPanel>
        </Grid>
    </Grid>
</Window>
'@

# Load main window
$reader = New-Object System.Xml.XmlNodeReader $mainXaml
$win = [Windows.Markup.XamlReader]::Load($reader)

# Controls
$EnabledChk      = $win.FindName('EnabledChk')
$AppNameBox      = $win.FindName('AppNameBox')
$AppIconBtn      = $win.FindName('AppIconBtn')
$AppIconText     = $win.FindName('AppIconText')
$NotifIconBtn    = $win.FindName('NotifIconBtn')
$NotifIconText   = $win.FindName('NotifIconText')
$NotifText       = $win.FindName('NotifText')
$NotifMelody     = $win.FindName('NotifMelody')
$NotifSummaryChk = $win.FindName('NotifSummaryChk')
$NotifSoundChk   = $win.FindName('NotifSoundChk')
$NotifTestBtn    = $win.FindName('NotifTestBtn')
$StopIconBtn     = $win.FindName('StopIconBtn')
$StopIconText    = $win.FindName('StopIconText')
$StopText        = $win.FindName('StopText')
$StopMelody      = $win.FindName('StopMelody')
$StopSummaryChk  = $win.FindName('StopSummaryChk')
$StopSoundChk    = $win.FindName('StopSoundChk')
$StopTestBtn     = $win.FindName('StopTestBtn')
$TestBothBtn     = $win.FindName('TestBothBtn')
$ResetBtn        = $win.FindName('ResetBtn')
$SaveBtn         = $win.FindName('SaveBtn')
$StatusText      = $win.FindName('StatusText')

# Fill ComboBoxes
foreach ($combo in @($NotifMelody, $StopMelody)) {
    foreach ($key in $MelodyPresets.Keys) {
        $item = New-Object System.Windows.Controls.ComboBoxItem
        $item.Content = $MelodyPresets[$key].Label
        $item.Tag = $key
        $combo.Items.Add($item) | Out-Null
    }
}

# UI <-> Config
function Set-ComboToPreset {
    param([System.Windows.Controls.ComboBox]$Combo, [string]$Preset)
    foreach ($it in $Combo.Items) {
        if ($it.Tag -eq $Preset) { $Combo.SelectedItem = $it; return }
    }
    if ($Combo.Items.Count -gt 0) { $Combo.SelectedIndex = 0 }
}

function Get-PropOr {
    param($Obj, [string]$Key, $Default)
    if ($null -eq $Obj) { return $Default }
    try {
        $v = $Obj.$Key
        if ($null -ne $v) { return $v }
    } catch {}
    return $Default
}

function Apply-ConfigToUI {
    param($cfg)
    $defaults = Get-DefaultConfig
    $EnabledChk.IsChecked      = [bool](Get-PropOr -Obj $cfg -Key 'enabled' -Default $true)
    $AppNameBox.Text           = "$(Get-PropOr -Obj $cfg.app -Key 'name' -Default 'Claude Code')"
    $AppIconText.Text          = "$(Get-PropOr -Obj $cfg.app -Key 'icon' -Default '🤖')"
    $NotifIconText.Text        = "$(Get-PropOr -Obj $cfg.notification -Key 'emoji'        -Default $defaults.notification.emoji)"
    $NotifText.Text            = "$(Get-PropOr -Obj $cfg.notification -Key 'text'         -Default $defaults.notification.text)"
    Set-ComboToPreset -Combo $NotifMelody -Preset "$(Get-PropOr -Obj $cfg.notification -Key 'melodyPreset' -Default 'doorbell')"
    $NotifSummaryChk.IsChecked = [bool](Get-PropOr -Obj $cfg.notification -Key 'showSummary' -Default $true)
    $NotifSoundChk.IsChecked   = [bool](Get-PropOr -Obj $cfg.notification -Key 'playSound'   -Default $true)
    $StopIconText.Text         = "$(Get-PropOr -Obj $cfg.stop -Key 'emoji' -Default $defaults.stop.emoji)"
    $StopText.Text             = "$(Get-PropOr -Obj $cfg.stop -Key 'text'  -Default $defaults.stop.text)"
    Set-ComboToPreset -Combo $StopMelody -Preset "$(Get-PropOr -Obj $cfg.stop -Key 'melodyPreset' -Default 'triumph')"
    $StopSummaryChk.IsChecked  = [bool](Get-PropOr -Obj $cfg.stop -Key 'showSummary' -Default $true)
    $StopSoundChk.IsChecked    = [bool](Get-PropOr -Obj $cfg.stop -Key 'playSound'   -Default $true)
}

function Build-ConfigFromUI {
    [ordered]@{
        version = 3
        enabled = [bool]$EnabledChk.IsChecked
        app = [ordered]@{
            name  = $AppNameBox.Text
            icon  = $AppIconText.Text
            appId = 'ClaudeCode.Notify'
        }
        notification = [ordered]@{
            emoji        = $NotifIconText.Text
            text         = $NotifText.Text
            melodyPreset = if ($NotifMelody.SelectedItem) { $NotifMelody.SelectedItem.Tag } else { 'doorbell' }
            customMelody = $null
            showSummary  = [bool]$NotifSummaryChk.IsChecked
            playSound    = [bool]$NotifSoundChk.IsChecked
        }
        stop = [ordered]@{
            emoji        = $StopIconText.Text
            text         = $StopText.Text
            melodyPreset = if ($StopMelody.SelectedItem) { $StopMelody.SelectedItem.Tag } else { 'triumph' }
            customMelody = $null
            showSummary  = [bool]$StopSummaryChk.IsChecked
            playSound    = [bool]$StopSoundChk.IsChecked
        }
    }
}

# === Emoji Picker ===
function Show-EmojiPicker {
    param([string]$Current)

    [xml]$pickerXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="아이콘 선택"
        Width="560" Height="600"
        Background="#F4F0EA"
        FontFamily="Segoe UI" Foreground="#2F2620"
        WindowStartupLocation="CenterOwner"
        ResizeMode="NoResize" ShowInTaskbar="False">
    <Grid Margin="20">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <TextBlock Grid.Row="0" Text="✨ 귀여운 아이콘 고르기" FontSize="18" FontWeight="SemiBold" Margin="0,0,0,14"/>
        <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" Background="#FFFBF5" Padding="14" CanContentScroll="False">
            <StackPanel x:Name="CategoryStack"/>
        </ScrollViewer>
        <StackPanel Grid.Row="2" Orientation="Horizontal" Margin="0,14,0,0">
            <TextBlock Text="직접 입력:" Foreground="#8C8C99" FontSize="12" VerticalAlignment="Center" Margin="0,0,8,0"/>
            <TextBox x:Name="CustomBox" Width="120" Background="#FFFBF5" Foreground="#2F2620" BorderBrush="#E0D5C8" BorderThickness="1" Padding="8,6" FontSize="14" FontFamily="Segoe UI Emoji"/>
            <Button x:Name="UseCustomBtn" Content="사용" Margin="8,0,0,0" Background="#EDE3D4" Foreground="#2F2620" BorderThickness="0" Padding="12,7" Cursor="Hand"/>
        </StackPanel>
        <StackPanel Grid.Row="3" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,14,0,0">
            <Button x:Name="CancelBtn" Content="취소" Background="#EDE3D4" Foreground="#2F2620" BorderThickness="0" Padding="14,9" Margin="0,0,8,0" Cursor="Hand"/>
        </StackPanel>
    </Grid>
</Window>
'@
    $r2 = New-Object System.Xml.XmlNodeReader $pickerXaml
    $pw = [Windows.Markup.XamlReader]::Load($r2)
    $pw.Owner = $win

    $stack     = $pw.FindName('CategoryStack')
    $customBox = $pw.FindName('CustomBox')
    $useCustom = $pw.FindName('UseCustomBtn')
    $cancelBtn = $pw.FindName('CancelBtn')

    $script:_pickedEmoji = $null

    foreach ($catName in $EmojiCatalog.Keys) {
        $lbl = New-Object System.Windows.Controls.TextBlock
        $lbl.Text = $catName
        $lbl.Foreground = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromRgb(140,140,153))
        $lbl.FontSize = 11
        $lbl.Margin = New-Object System.Windows.Thickness 0, 8, 0, 6
        $stack.Children.Add($lbl) | Out-Null

        $wrap = New-Object System.Windows.Controls.WrapPanel
        $wrap.Orientation = [System.Windows.Controls.Orientation]::Horizontal
        $wrap.Margin = New-Object System.Windows.Thickness 0, 0, 0, 10

        foreach ($emoji in $EmojiCatalog[$catName]) {
            $btn = New-Object System.Windows.Controls.Button
            $btn.Width = 46; $btn.Height = 46
            $btn.Margin = New-Object System.Windows.Thickness 3
            $btn.BorderThickness = New-Object System.Windows.Thickness 0
            $btn.Background = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromRgb(240,232,220))
            $btn.Cursor = [System.Windows.Input.Cursors]::Hand
            $btn.FontSize = 22
            $btn.FontFamily = New-Object System.Windows.Media.FontFamily 'Segoe UI Emoji'
            $btn.Content = $emoji
            $btn.ToolTip = $emoji
            # 모노크롬 기호(✱✦✧◈◇◆✴️ 등)는 코럴로 — 클로드 캐릭터 느낌
            if ('✱✦✧◈◇◆✴️*' -match [regex]::Escape($emoji) -or $emoji -eq '✱' -or $emoji -eq '✦' -or $emoji -eq '✧' -or $emoji -eq '◈' -or $emoji -eq '◇' -or $emoji -eq '◆' -or $emoji -eq '✴️') {
                $btn.Foreground = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromRgb(217,119,87))
                $btn.FontWeight = [System.Windows.FontWeights]::Bold
            } else {
                $btn.Foreground = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromRgb(47,38,32))
            }
            if ($emoji -eq $Current) {
                $btn.Background = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromRgb(217,119,87))
                $btn.Foreground = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromRgb(255,251,245))
            }
            $btn.Add_Click({
                $script:_pickedEmoji = $this.Content
                $pw.DialogResult = $true
                $pw.Close()
            }.GetNewClosure())
            $wrap.Children.Add($btn) | Out-Null
        }
        $stack.Children.Add($wrap) | Out-Null
    }

    $useCustom.Add_Click({
        $v = $customBox.Text.Trim()
        if ($v) { $script:_pickedEmoji = $v; $pw.DialogResult = $true; $pw.Close() }
    })
    $cancelBtn.Add_Click({ $pw.DialogResult = $false; $pw.Close() })

    $result = $pw.ShowDialog()
    if ($result -eq $true) { return $script:_pickedEmoji } else { return $null }
}

# === Events ===
$AppIconBtn.Add_Click({
    $picked = Show-EmojiPicker -Current $AppIconText.Text
    if ($picked) { $AppIconText.Text = $picked; $StatusText.Text = "앱 아이콘: $picked  (저장 필요)" }
})
$NotifIconBtn.Add_Click({
    $picked = Show-EmojiPicker -Current $NotifIconText.Text
    if ($picked) { $NotifIconText.Text = $picked; $StatusText.Text = "응답 필요 아이콘: $picked  (저장 필요)" }
})
$StopIconBtn.Add_Click({
    $picked = Show-EmojiPicker -Current $StopIconText.Text
    if ($picked) { $StopIconText.Text = $picked; $StatusText.Text = "작업 완료 아이콘: $picked  (저장 필요)" }
})

$NotifTestBtn.Add_Click({
    $preset = if ($NotifMelody.SelectedItem) { $NotifMelody.SelectedItem.Tag } else { 'doorbell' }
    Invoke-MelodyPreview -PresetName $preset
})
$StopTestBtn.Add_Click({
    $preset = if ($StopMelody.SelectedItem) { $StopMelody.SelectedItem.Tag } else { 'triumph' }
    Invoke-MelodyPreview -PresetName $preset
})

$TestBothBtn.Add_Click({
    $tmp = Build-ConfigFromUI
    Save-NotifyConfig -Config $tmp
    ConvertTo-IcoFromEmoji -Emoji $tmp.notification.emoji -OutPath (Join-Path $IconsDir 'notification.ico')
    ConvertTo-IcoFromEmoji -Emoji $tmp.stop.emoji         -OutPath (Join-Path $IconsDir 'stop.ico')
    Start-Process -FilePath 'powershell' -ArgumentList @('-NoProfile','-WindowStyle','Hidden','-ExecutionPolicy','Bypass','-File',$NotifyPs1,'-Type','notification') -WindowStyle Hidden
    Start-Sleep -Milliseconds 1500
    Start-Process -FilePath 'powershell' -ArgumentList @('-NoProfile','-WindowStyle','Hidden','-ExecutionPolicy','Bypass','-File',$NotifyPs1,'-Type','stop') -WindowStyle Hidden
    $StatusText.Text = "전체 미리듣기 실행 (현재 UI 값 저장됨)"
})

$ResetBtn.Add_Click({
    Apply-ConfigToUI -cfg (Get-DefaultConfig)
    $StatusText.Text = "기본값으로 초기화 — 💾 저장 누르면 적용돼요"
})

$SaveBtn.Add_Click({
    try {
        $cfg = Build-ConfigFromUI
        Save-NotifyConfig -Config $cfg
        ConvertTo-IcoFromEmoji -Emoji $cfg.notification.emoji -OutPath (Join-Path $IconsDir 'notification.ico')
        ConvertTo-IcoFromEmoji -Emoji $cfg.stop.emoji         -OutPath (Join-Path $IconsDir 'stop.ico')

        # 앱 아이콘 .ico 재생성 + AppUserModelID 레지스트리 업데이트
        $claudeIco = Join-Path $IconsDir 'claude.ico'
        ConvertTo-IcoFromEmoji -Emoji $cfg.app.icon -OutPath $claudeIco -Size 64
        $regPath = "HKCU:\Software\Classes\AppUserModelId\$($cfg.app.appId)"
        if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
        Set-ItemProperty -Path $regPath -Name 'DisplayName' -Value $cfg.app.name -Type String
        Set-ItemProperty -Path $regPath -Name 'IconUri' -Value $claudeIco -Type String

        $StatusText.Text = "✓ 저장됨  (" + (Get-Date -Format 'HH:mm:ss') + ") — 앱 이름/아이콘 다음 알람부터 반영"
    } catch {
        $StatusText.Text = "❗ 저장 실패: " + $_.Exception.Message
    }
})

Apply-ConfigToUI -cfg (Read-NotifyConfig)
$StatusText.Text = "변경 후 💾 저장을 눌러야 반영돼요"

[void]$win.ShowDialog()
