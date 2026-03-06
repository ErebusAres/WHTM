local _, ns = ...
local WHTM = ns.WHTM

function WHTM:InitializeMinimap()
    local ldb = LibStub("LibDataBroker-1.1", true)
    local icon = LibStub("LibDBIcon-1.0", true)
    if not ldb or not icon then
        self:Printf("Minimap libraries not loaded; minimap icon disabled.")
        return
    end

    self.ldbObject = ldb:NewDataObject("WHTM", {
        type = "launcher",
        icon = "Interface\\AddOns\\WHTM\\images\\whtm_icon_ring.tga",
        label = "WHTM",
        text = "WHTM",
        OnClick = function(_, button)
            if button == "RightButton" then
                WHTM:OpenOptions()
            else
                WHTM:ToggleMainFrame()
            end
        end,
        OnTooltipShow = function(tt)
            tt:AddLine("WHTM")
            tt:AddLine("Left-click: Toggle tracker", 1, 1, 1)
            tt:AddLine("Right-click: Open options", 1, 1, 1)
        end,
    })

    icon:Register("WHTM", self.ldbObject, self.db.profile.minimap)
    self:RefreshMinimapIcon()
end

function WHTM:RefreshMinimapIcon()
    local icon = LibStub("LibDBIcon-1.0", true)
    if not icon then
        return
    end
    icon:Refresh("WHTM", self.db.profile.minimap)

    if self.db.profile.minimap.hide then
        icon:Hide("WHTM")
    else
        icon:Show("WHTM")
        local button = icon.objects and icon.objects["WHTM"]
        if button and not button.WHTMGoldRing then
            local ring = button:CreateTexture(nil, "OVERLAY")
            ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
            ring:SetPoint("CENTER", button, "CENTER", 10, -10)
            ring:SetWidth(53)
            ring:SetHeight(53)
            ring:SetVertexColor(1.0, 0.82, 0.0, 0.95)
            button.WHTMGoldRing = ring
        end
    end
end
