-- Tungsten cube assets are mounted from chudmorse_content_pack.
-- resource.AddFile on a .mdl also sends its .vvd/.vtx/.phy; on a .vmt its matching .vtf.
resource.AddFile("models/linnaeus/tungsten_cube.mdl")
resource.AddFile("models/linnaeus/weaps/v_tungsten.mdl")
resource.AddFile("models/linnaeus/weaps/w_tungsten.mdl")
resource.AddFile("materials/models/linnaeus/tungsten/tungstencube.vmt")
for _, vtf in ipairs({"tngstn", "tngstn_rough", "flat_normal", "righthererightnow", "gray", "classicmap", "cubetest"}) do
    resource.AddSingleFile("materials/models/linnaeus/tungsten/" .. vtf .. ".vtf")
end
resource.AddFile("materials/entities/tungstencubeicon.vmt")
resource.AddSingleFile("materials/entities/cubekillicon.png")
