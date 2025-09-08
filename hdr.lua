local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local QualitySettings = {
    Low = {
        BlurAmount = 4,
        BlurAmplifier = 2,
        BloomIntensity = 0.3,
        BloomSize = 12,
        SunRaysIntensity = 0.03,
        DepthOfFieldEnabled = false,
        AtmosphereDensity = 0.1,
        ShadowSoftness = 0.6,
        FogEnd = 2500,
        SkyEnabled = false,
        SpecularScale = 0.2 -- Ditambahkan untuk kilau
    },
    Medium = {
        BlurAmount = 8,
        BlurAmplifier = 5,
        BloomIntensity = 0.7,
        BloomSize = 20,
        SunRaysIntensity = 0.08,
        DepthOfFieldEnabled = true,
        AtmosphereDensity = 0.25,
        ShadowSoftness = 0.4,
        FogEnd = 1500,
        SkyEnabled = true,
        SpecularScale = 0.5 -- Ditambahkan untuk kilau
    },
    High = {
        BlurAmount = 12,
        BlurAmplifier = 8,
        BloomIntensity = 1.5,
        BloomSize = 36,
        SunRaysIntensity = 0.2,
        DepthOfFieldEnabled = true,
        AtmosphereDensity = 0.4,
        ShadowSoftness = 0.05,
        FogEnd = 800,
        SkyEnabled = true,
        SpecularScale = 1.0 -- Ditambahkan untuk kilau maksimal
    }
}

local CurrentQuality = "High"
local Camera = Workspace.CurrentCamera
local LastVector = Camera.CFrame.LookVector
local MotionBlur = nil

local function SetupEffects(quality)
    for _, effect in pairs(Lighting:GetChildren()) do
        if effect:IsA("PostEffect") or effect:IsA("Atmosphere") then
            effect:Destroy()
        end
    end
    if MotionBlur then
        MotionBlur:Destroy()
    end

    local settings = QualitySettings[quality]

    MotionBlur = Instance.new("BlurEffect")
    MotionBlur.Name = "MotionBlur"
    MotionBlur.Size = 0
    MotionBlur.Parent = Camera

    local Bloom = Instance.new("BloomEffect")
    Bloom.Name = "Bloom"
    Bloom.Intensity = settings.BloomIntensity
    Bloom.Size = settings.BloomSize
    Bloom.Threshold = 0.8
    Bloom.Parent = Lighting

    local ColorCorrection = Instance.new("ColorCorrectionEffect")
    ColorCorrection.Name = "ColorCorrection"
    ColorCorrection.Brightness = 0.1
    ColorCorrection.Contrast = 0.3
    ColorCorrection.Saturation = 0.5
    ColorCorrection.TintColor = Color3.fromRGB(255, 235, 220)
    ColorCorrection.Parent = Lighting

    local SunRays = Instance.new("SunRaysEffect")
    SunRays.Name = "SunRays"
    SunRays.Intensity = settings.SunRaysIntensity
    SunRays.Spread = 0.9
    SunRays.Parent = Lighting

    local DepthOfField = Instance.new("DepthOfFieldEffect")
    DepthOfField.Name = "DepthOfField"
    DepthOfField.Enabled = settings.DepthOfFieldEnabled
    DepthOfField.FarIntensity = 0.7
    DepthOfField.FocusDistance = 40
    DepthOfField.InFocusRadius = 10
    DepthOfField.NearIntensity = 0.4
    DepthOfField.Parent = Lighting

    local Atmosphere = Instance.new("Atmosphere")
    Atmosphere.Name = "Atmosphere"
    Atmosphere.Density = settings.AtmosphereDensity
    Atmosphere.Offset = 0.3
    Atmosphere.Color = Color3.fromRGB(255, 240, 230)
    Atmosphere.Glare = 0.4
    Atmosphere.Haze = 0.5
    Atmosphere.Parent = Lighting

    -- Tambahan efek Glow untuk menonjolkan detail
    local Glow = Instance.new("BloomEffect")
    Glow.Name = "Glow"
    Glow.Intensity = 0.2
    Glow.Size = 10
    Glow.Threshold = 1.5
    Glow.Parent = Lighting
end

local function SetupLighting(quality)
    local settings = QualitySettings[quality]
    Lighting.Brightness = 2.5
    Lighting.GlobalShadows = true
    Lighting.ShadowSoftness = settings.ShadowSoftness
    Lighting.ClockTime = 17.5
    Lighting.Ambient = Color3.fromRGB(70, 60, 80)
    Lighting.OutdoorAmbient = Color3.fromRGB(100, 90, 110)
    Lighting.FogEnd = settings.FogEnd
    Lighting.FogColor = Color3.fromRGB(255, 220, 200)
    Lighting.EnvironmentDiffuseScale = 0.5
    Lighting.EnvironmentSpecularScale = settings.SpecularScale -- Disesuaikan untuk kilau
    Lighting.Technology = Enum.Technology.Voxel -- Diganti ke Voxel untuk bayangan lebih baik
end

local function UpdateMotionBlur(quality)
    local settings = QualitySettings[quality]
    RunService.RenderStepped:Connect(function(deltaTime)
        local CurrentVector = Camera.CFrame.LookVector
        local Delta = (CurrentVector - LastVector).Magnitude
        local BlurSize = math.clamp(settings.BlurAmount * Delta * settings.BlurAmplifier * deltaTime * 30, 0, 30)
        MotionBlur.Size = MotionBlur.Size + (BlurSize - MotionBlur.Size) * 0.1
        LastVector = CurrentVector
    end)
end

local function SetupQualityToggle()
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.F1 then
            CurrentQuality = "Low"
        elseif input.KeyCode == Enum.KeyCode.F2 then
            CurrentQuality = "Medium"
        elseif input.KeyCode == Enum.KeyCode.F3 then
            CurrentQuality = "High"
        end
        SetupEffects(CurrentQuality) -- Hapus SetupSky karena tidak ada di kode awal
        SetupLighting(CurrentQuality)
        print("Qualidade alterada para: " .. CurrentQuality)
    end)
end

local function HandleCameraChange()
    Workspace.Changed:Connect(function(property)
        if property == "CurrentCamera" then
            Camera = Workspace.CurrentCamera
            LastVector = Camera.CFrame.LookVector
            if MotionBlur then
                MotionBlur.Parent = Camera
            end
        end
    end)
end

local function Initialize()
    SetupLighting(CurrentQuality)
    SetupEffects(CurrentQuality)
    UpdateMotionBlur(CurrentQuality)
    SetupQualityToggle()
    HandleCameraChange()
end

Initialize()
