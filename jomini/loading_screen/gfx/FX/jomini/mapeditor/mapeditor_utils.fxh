Includes = {
	"cw/heightmap.fxh"
	"cw/terrain.fxh"
	"jomini/mapeditor/mapeditor_gruvbox.fxh"
}

Code
[[
	float3 TerrainEditorCheckers( float3 CheckersBaseColor, float2 Position, float Amount )
	{
		float3 CheckersColor = lerp( CheckersBaseColor, CHECKERS_COLOR_TOP, 0.75 );
		float2 CheckersPos = round( Position * CHECKERS_COUNT );
		float3 CheckersTexture = (int(CheckersPos.x + CheckersPos.y) % 2) == 0 ? CheckersBaseColor : CheckersColor;
		CheckersTexture = lerp( CheckersBaseColor, CheckersTexture, Amount );
		return CheckersTexture;
	}

	bool TerrainEditorBrushOutlineInternal( inout float4 ColorOut, in float2 CursorPos, in float2 FragmentPos, in float OutlineWidth )
	{
		float Distance = distance( CursorPos, FragmentPos );

		// Inner radius, potentially affected by brush hardness.
		if( Distance > BrushInnerRadius && Distance < (BrushInnerRadius + OutlineWidth) )
		{
			ColorOut.rgb = GRUVBOX_LIGHT_BLUE;
			ColorOut.a = 1;
			return true;
		}

		// Outer radius, including border pixels.
		if( Distance > BrushOuterRadius && Distance < (BrushOuterRadius + OutlineWidth) )
		{
			ColorOut.rgb = GRUVBOX_LIGHT_RED;
			ColorOut.a = 1;
			return true;
		}
		return false;
	}

	void TerrainEditorBrushOutline( inout float4 ColorOut, in float2 CursorPos, in float2 FragmentPos, in float CameraHeight )
	{
		float CameraHeightFactor = (clamp( CameraHeight, BRUSH_OUTLINE_DIST_MIN, BRUSH_OUTLINE_DIST_MAX ) - BRUSH_OUTLINE_DIST_MIN) / ( BRUSH_OUTLINE_DIST_MAX - BRUSH_OUTLINE_DIST_MIN );
		float OutlineWidth = lerp( BRUSH_OUTLINE_WIDTH_MIN, BRUSH_OUTLINE_WIDTH_MAX, CameraHeightFactor );

		if( TerrainEditorBrushOutlineInternal( ColorOut, CursorPos, FragmentPos, OutlineWidth ) )
			return;

	#ifdef TERRAIN_WRAP_X
		float WorldWidth = 1.0f / _WorldSpaceToTerrain0To1.x;
		if( TerrainEditorBrushOutlineInternal( ColorOut, float2( CursorPos.x - WorldWidth, CursorPos.y ), FragmentPos, OutlineWidth ) )
			return;
		if( TerrainEditorBrushOutlineInternal( ColorOut, float2( CursorPos.x + WorldWidth, CursorPos.y ), FragmentPos, OutlineWidth ) )
			return;
	#endif
	}
]]
