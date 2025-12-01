Includes = {
	"cw/terrain.fxh"
	"cw/heightmap.fxh"
	"cw/shadow.fxh"
	"cw/utility.fxh"
	"cw/lighting_util.fxh"
	"jomini/jomini_lighting.fxh"
	"jomini/mapeditor/mapeditor_constants.fxh"
	"jomini/mapeditor/mapeditor_utils.fxh"
	"jomini/mapeditor/mapeditor_gruvbox.fxh"
	"cw/terrain2_shader_mains.fxh"
}

VertexShader =
{
	MainCode VertexShader
	{
		Input = "STerrain2VertexInput"
		Output = "STerrain2VertexOutput"
		Code
		[[
			PDX_MAIN
			{
				return Terrain2_VertexShaderMain( Input );
			}
		]]
	}
}

PixelShader =
{
	TextureSampler MaskTexture
	{
		Index = 7
		MagFilter = "Point"
		MinFilter = "Point"
		MipFilter = "Point"
		SampleModeU = "Clamp"
		SampleModeV = "Clamp"
	}

	TextureSampler MaskPaletteTexture
	{
		Index = 8
		MagFilter = "Point"
		MinFilter = "Point"
		MipFilter = "Point"
		SampleModeU = "Clamp"
		SampleModeV = "Clamp"
	}

	MainCode NoPixelShader
	{
		Input = "STerrain2VertexOutput"
		Output = "PDX_COLOR"
		Code
		[[
			PDX_MAIN
			{
				discard;
				return float4(0, 0, 0, 0);
			}
		]]
	}

	MainCode Select
	{
		Input = "STerrain2VertexOutput"
		Output = "PDX_COLOR"
		Code
		[[
			PDX_MAIN
			{
				float4 FinalColor = float4( 0, 0, 0, 0 );

				if( Input.WorldSpacePosition.x >= SelectMin.x &&
					Input.WorldSpacePosition.x <= SelectMax.x &&
					Input.WorldSpacePosition.z >= SelectMin.y &&
					Input.WorldSpacePosition.z <= SelectMax.y)
				{
					FinalColor = float4( GRUVBOX_DARK_GREEN, 0.4 );
				}

				return FinalColor;
			}
		]]
	}

	MainCode BrushOutline
	{
		Input = "STerrain2VertexOutput"
		Output = "PDX_COLOR"
		Code
		[[
			PDX_MAIN
			{
				float4 FinalColor = float4( 0, 0, 0, 0 );
				TerrainEditorBrushOutline( FinalColor, CursorPos, Input.WorldSpacePosition.xz, CameraPosition.y );
				return FinalColor;
			}
		]]
	}

	MainCode MaskOverlay
	{
		ConstantBuffer( PdxConstantBuffer0 )
		{
			float4 _MaskOverlayRGBA;
			float2 _MaskSize;
		}

		Input = "STerrain2VertexOutput"
		Output = "PDX_COLOR"
		Code
		[[
			PDX_MAIN
			{
				float2 UV = ( Input.WorldSpacePosition.xz * _WorldSpaceToTerrain0To1 ); // * _MaskSize;

			#ifdef MASK_OVERLAY_RGB
				return PdxTex2D( MaskTexture, UV ) * _MaskOverlayRGBA;
			#elif defined( MASK_OVERLAY_RGB_PALETTE )
				#ifdef PALETTE_32
					float4 IndexToReconstruct = PdxTex2D( MaskTexture, UV ).rgba;

					int4 ColorIndices = int4( int( IndexToReconstruct.r * 255.0 ),
						int( IndexToReconstruct.g * 255.0 ),
						int( IndexToReconstruct.b * 255.0 ),
						int( IndexToReconstruct.a * 255.0 ) );

					int ColorIndex = ( ColorIndices.r & 0x000000ff )
						| ( ( ColorIndices.g << 8 ) & 0x0000ff00 )
						| ( ( ColorIndices.b << 16 ) & 0x00ff0000 )
						| ( ( ColorIndices.a << 24 ) & 0xff000000 );

				#elif defined ( PALETTE_16 )
					int ColorIndex = int( PdxTex2D( MaskTexture, UV ).r * 65535.0 );
				#elif defined ( PALETTE_8 )
					int ColorIndex = int( PdxTex2D( MaskTexture, UV ).r * 255.0 );
				#endif

				float2 PaletteSize;
				PdxTex2DSize( MaskPaletteTexture, PaletteSize );
				int PaletteWidth = int( PaletteSize.x );
				int Column = ColorIndex % PaletteWidth;
				int Row = ColorIndex / PaletteWidth;
				return PdxTex2DLoad0( MaskPaletteTexture, int2( Column, Row ) ).bgra * _MaskOverlayRGBA;
			#else
				float Opacity = PdxTex2D( MaskTexture, UV ).r;
				return float4( _MaskOverlayRGBA.rgb, _MaskOverlayRGBA.a * Opacity );
			#endif
			}
		]]
	}

	MainCode PartialTerrainOverlay
	{
		ConstantBuffer( PdxConstantBuffer0 )
		{
			float2 OverlayWorldStart;
			float2 OverlayWorldEnd;
			float4 OverlayTexelSize;
			float Opacity;
			int FlipY;
		}

		TextureSampler OverlayTexture
		{
			Ref = EditorTerrainOverlayTexture
			MagFilter = "Linear"
			MinFilter = "Linear"
			MipFilter = "Linear"
			SampleModeU = "Clamp"
			SampleModeV = "Clamp"
		}

		Input = "STerrain2VertexOutput"
		Output = "PDX_COLOR"
		Code
		[[
			PDX_MAIN
			{
				if ( Input.WorldSpacePosition.x < OverlayWorldStart.x || Input.WorldSpacePosition.z < OverlayWorldStart.y || Input.WorldSpacePosition.x > OverlayWorldEnd.x || Input.WorldSpacePosition.z > OverlayWorldEnd.y )
				{
					discard;
				}

				float2 UV = ( ( Input.WorldSpacePosition.xz - OverlayWorldStart ) / ( OverlayWorldEnd - OverlayWorldStart ) );
				if ( FlipY == 1 )
				{
					UV.y = 1 - UV.y;
				}
				float4 OverlayRGBA = PdxTex2D( OverlayTexture, UV );
				return float4( OverlayRGBA.rgb, OverlayRGBA.a * Opacity );
			}
		]]
	}

	MainCode PartialTerrainOverlayNoInterpolation
	{
		ConstantBuffer( PdxConstantBuffer0 )
		{
			float2 OverlayWorldStart;
			float2 OverlayWorldEnd;
			float4 OverlayTexelSize;
			float Opacity;
			int FlipY;
		}

		TextureSampler OverlayTexture
		{
			Ref = EditorTerrainOverlayTexture
			MagFilter = "Point"
			MinFilter = "Point"
			MipFilter = "Point"
			SampleModeU = "Clamp"
			SampleModeV = "Clamp"
		}

		Input = "STerrain2VertexOutput"
		Output = "PDX_COLOR"
		Code
		[[
			PDX_MAIN
			{
				if ( Input.WorldSpacePosition.x < OverlayWorldStart.x || Input.WorldSpacePosition.z < OverlayWorldStart.y || Input.WorldSpacePosition.x > OverlayWorldEnd.x || Input.WorldSpacePosition.z > OverlayWorldEnd.y )
				{
					discard;
				}

				float2 UV = ( (Input.WorldSpacePosition.xz - OverlayWorldStart) / (OverlayWorldEnd - OverlayWorldStart) );
				if ( FlipY == 1 )
				{
					UV.y = 1 - UV.y;
				}
				float4 OverlayRGBA = PdxTex2D( OverlayTexture, UV );
				return float4( OverlayRGBA.rgb, OverlayRGBA.a * Opacity );
			}
		]]
	}
}

BlendState BlendStateOverlay
{
	BlendEnable = yes
	SourceBlend = "SRC_ALPHA"
	DestBlend = "INV_SRC_ALPHA"
}

BlendState BlendStateAdd
{
	BlendEnable = yes
	SourceBlend = "SRC_ALPHA"
	DestBlend = "ONE"
	WriteMask = "RED|GREEN|BLUE|ALPHA"
}

DepthStencilState DepthStencilStateOverlay
{
	DepthEnable = no
}

Effect PdxTerrainSelect
{
	VertexShader = "VertexShader"
	PixelShader = "Select"
	BlendState = BlendStateOverlay
	DepthStencilState = DepthStencilStateOverlay
}

Effect PdxTerrainBrushOutline
{
	VertexShader = "VertexShader"
	PixelShader = "BrushOutline"
	BlendState = BlendStateOverlay
	DepthStencilState = DepthStencilStateOverlay
}

Effect PdxTerrainMaskOverlay
{
	VertexShader = "VertexShader"
	PixelShader = "MaskOverlay"
	BlendState = BlendStateOverlay
	DepthStencilState = DepthStencilStateOverlay
}

Effect PdxPartialTerrainOverlay
{
	VertexShader = "VertexShader"
	PixelShader = "PartialTerrainOverlay"
	BlendState = BlendStateOverlay
	DepthStencilState = DepthStencilStateOverlay
}

Effect PdxPartialTerrainOverlayNoInterpolation
{
	VertexShader = "VertexShader"
	PixelShader = "PartialTerrainOverlayNoInterpolation"
	BlendState = BlendStateOverlay
	DepthStencilState = DepthStencilStateOverlay
}
