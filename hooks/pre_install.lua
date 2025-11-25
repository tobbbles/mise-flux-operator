-- hooks/pre_install.lua
-- Returns download information for a specific version
-- Documentation: https://mise.jdx.dev/tool-plugin-development.html#preinstall-hook

-- Helper function for platform detection
local function get_platform()
    -- RUNTIME object is provided by mise/vfox
    -- RUNTIME.osType: "Windows", "Linux", "Darwin"
    -- RUNTIME.archType: "amd64", "386", "arm64", etc.

    local os_name = RUNTIME.osType:lower() -- luacheck: ignore RUNTIME
    local arch = RUNTIME.archType -- luacheck: ignore RUNTIME

    -- Map to your tool's platform naming convention
    -- Adjust these mappings based on how your tool names its releases
    local platform_map = {
        ["darwin"] = {
            ["amd64"] = "darwin_amd64",
            ["arm64"] = "darwin_arm64",
        },
        ["linux"] = {
            ["amd64"] = "linux_amd64",
            ["arm64"] = "linux_arm64",
            ["386"] = "linux_386",
        },
        ["windows"] = {
            ["amd64"] = "windows_amd64",
            ["386"] = "windows_386",
        },
    }

    local os_map = platform_map[os_name]
    if os_map then
        return os_map[arch] or "linux-amd64" -- fallback
    end

    -- Default fallback
    return "linux-amd64"
end

function PLUGIN:PreInstall(ctx)
    local version = ctx.version

    local platform = get_platform()
    local filename = "flux-operator_" .. version .. "_" .. platform .. ".tar.gz"

    -- wrong: https://github.com/controlplaneio-fluxcd/flux-operator/releases/download/v0.34.0/flux-operator_0.34.0darwin_arm64.tar.gz
    -- right: https://github.com/controlplaneio-fluxcd/flux-operator/releases/download/v0.34.0/flux-operator-mcp_0.34.0_darwin_arm64.tar.gz
    local url = "https://github.com/controlplaneio-fluxcd/flux-operator/releases/download/v"
        .. version
        .. "/flux-operator_"
        .. version
        .. "_"
        .. platform
        .. ".tar.gz"

    local checksums_url = "https://github.com/controlplaneio-fluxcd/flux-operator/releases/download/v"
        .. version
        .. "/flux-operator_"
        .. version
        .. "_checksums.txt"

    local http = require("http")
    local resp, err = http.get({
        url = checksums_url,
    })
    if err ~= nil then
        error("Failed to fetch checksums: " .. err)
    end
    if resp.status_code ~= 200 then
        error("GitHub API returned status " .. resp.status_code .. ": " .. resp.body)
    end

    local sha256 = nil

    for line in resp.body:gmatch("[^\r\n]+") do
        -- Use plain text find (4th arg = true) to avoid pattern issues with dots in filename
        if line:find(filename, 1, true) then
            sha256 = line:match("^([a-fA-F0-9]+)")
            break
        end
    end
    if sha256 == nil then
        error("Failed to find checksum for " .. filename)
    end

    return {
        version = version,
        url = url,
        sha256 = sha256,
        note = "Downloading flux-operator " .. version,
        -- addition = { -- Optional: download additional components
        --     {
        --         name = "component",
        --         url = "https://example.com/component.tar.gz"
        --     }
        -- }
    }
end
