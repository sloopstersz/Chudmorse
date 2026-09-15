hook.Add( "PreLoadAnimations", "DynaBase.wwestuffyesyes", function( gender )
  if gender == WOS_DYNABASE.MALE then
    IncludeModel( "models/alagri/okd_anim.mdl" )
  elseif gender == WOS_DYNABASE.FEMALE then
    IncludeModel( "models/alagri/okd_anim.mdl" )
  elseif gender == WOS_DYNABASE.ZOMBIE then
    IncludeModel( "models/alagri/okd_anim.mdl" )
  end
end )

hook.Add( "PreLoadAnimations", "DynaBase.wwestuffyesyes", function( gender )
  if gender == WOS_DYNABASE.SHARED then
    IncludeModel( "models/alagri/okd_anim.mdl" )
  end
end )
