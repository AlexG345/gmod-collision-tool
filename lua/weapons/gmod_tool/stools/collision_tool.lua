local mode = TOOL.Mode -- Class name of the tool. (name of the .lua file) 

TOOL.Category		= "Construction"
TOOL.Name			= "#Tool."..mode..".listname"
TOOL.ConfigName		= ""
TOOL.ClientConVar[ "col_group" ] = "0"
TOOL.ClientConVar[ "remove_constr" ] = "1"
TOOL.ClientConVar[ "trace_col_group" ] = "0"
TOOL.ClientConVar[ "tooltip_enabled" ] = "1"

TOOL.Information = {
	{ name = "left" },
	{ name = "right" },
	{ name = "reload" },
}


if CLIENT then
	local t = "tool."..mode.."."
	language.Add( t.."listname",	"Collision Tool" )
	language.Add( t.."name",		"Collision Tool" )
	language.Add( t.."desc",		"Edit collision groups and create world no-collide constraints" )
	language.Add( t.."left",		"Change the collision group" )
	language.Add( t.."reload",		"Create or remove a no-collide constraint with the world" )
	language.Add( t.."right",		"Copy the collision group" )

	colEnums = {
		"COLLISION_GROUP_DEBRIS",
		"COLLISION_GROUP_DEBRIS_TRIGGER",
		"COLLISION_GROUP_INTERACTIVE_DEBRIS",
		"COLLISION_GROUP_INTERACTIVE",
		"COLLISION_GROUP_PLAYER",
		"COLLISION_GROUP_BREAKABLE_GLASS",
		"COLLISION_GROUP_VEHICLE",
		"COLLISION_GROUP_PLAYER_MOVEMENT",
		"COLLISION_GROUP_NPC",
		"COLLISION_GROUP_IN_VEHICLE",
		"COLLISION_GROUP_WEAPON",
		"COLLISION_GROUP_VEHICLE_CLIP",
		"COLLISION_GROUP_PROJECTILE",
		"COLLISION_GROUP_DOOR_BLOCKER",
		"COLLISION_GROUP_PASSABLE_DOOR",
		"COLLISION_GROUP_DISSOLVING",
		"COLLISION_GROUP_PUSHAWAY",
		"COLLISION_GROUP_NPC_ACTOR",
		"COLLISION_GROUP_NPC_SCRIPTED",
		"COLLISION_GROUP_WORLD"
	}
	colEnums[0] = "COLLISION_GROUP_NONE"

end


local function getCustomTrace( ply, col_group )

	local tr = util.GetPlayerTrace( ply )
	tr.mask = bit.bor( CONTENTS_SOLID, CONTENTS_MOVEABLE, CONTENTS_MONSTER, CONTENTS_WINDOW, CONTENTS_DEBRIS, CONTENTS_GRATE, CONTENTS_AUX )
	tr.collisiongroup = col_group or 0
	tr.mins = vector_origin
	tr.maxs = tr.mins
	local trace = util.TraceLine( tr )
	if ( !trace.Hit ) then trace = util.TraceHull( tr ) end
	return trace

end


function TOOL:LeftClick( trace )

	local ply = self:GetOwner()	
	local tcg = self:GetClientNumber( "trace_col_group" )
	if tcg ~= 0 then trace = getCustomTrace( ply, tcg ) end

	local ent = trace.Entity
	
	if IsValid( ent ) && ( ent:IsPlayer() ) then return false end
	if ent:IsWorld() then return end
	if not ent.SetCollisionGroup then return false end

	local col_group = self:GetClientNumber( "col_group" )
	local old_col_group = ent:GetCollisionGroup()

	if col_group == old_col_group then return true end

	undo.Create( "Collision Group Change ("..(ent:GetModel() or "?")..")" )
		undo.AddFunction(
		function( undo, entity, group )
			if not IsValid( entity ) then return false end
			entity:SetCollisionGroup( group )
		end,
		ent, old_col_group
		)
		undo.SetPlayer( ply )
	undo.Finish()

	ent:SetCollisionGroup( col_group )

	if CLIENT or game.SinglePlayer() then
		ply:EmitSound( "buttons/button9.wav" )
	end

	return true

end

function TOOL:RightClick( trace )

	local ent = trace.Entity

	if not ent.GetCollisionGroup then return false end

	local col_group = ent:GetCollisionGroup()
	if not col_group then return false end

	local cVarName = mode.."_col_group"

	if ( CLIENT or game.SinglePlayer() ) and col_group ~= GetConVar( cVarName ):GetInt() then
		self:GetOwner():EmitSound( "garrysmod/content_downloaded.wav", 75, 100 )
		RunConsoleCommand( cVarName, col_group )
	end

	return true

end

function TOOL:Reload( trace )

	local ent = trace.Entity

	if not IsValid( ent ) then return false end

	local noCollideTable = constraint.FindConstraints( ent, "NoCollide" )
	local worldEnt = game.GetWorld()
	local isLocal = CLIENT or game.SinglePlayer()

	for index, constr in ipairs(noCollideTable) do

		if constr.Ent1 == worldEnt or constr.Ent2 == worldEnt then

			local removeConstr = self:GetClientBool( "remove_constr" )
			if removeConstr then constr.Constraint:Remove() end

			if isLocal then
				local sndName = removeConstr and "buttons/button16.wav"or "buttons/lightswitch2.wav"
				self:GetOwner():EmitSound( sndName )
			end

			return removeConstr
		
		end

	end


	if SERVER then

		local ply = self:GetOwner()

		if not ply:CheckLimit( "constraints" ) then return false end

		local constr = constraint.NoCollide( worldEnt, ent, 0, trace.PhysicsBone or 0, true )
		if ( IsValid( constr ) ) then

			undo.Create( "No Collide (World)" )
				undo.AddEntity( constr )
				undo.SetPlayer( ply )
				undo.SetCustomUndoText( "Undone #tool.nocollide.name" )
			undo.Finish( "#tool.nocollide.name" )

			ply:AddCount( "constraints", constr )
			ply:AddCleanup( "constraints", constr )

		end
	
	end



	if isLocal then self:GetOwner():EmitSound( "buttons/button14.wav" ) end

	return true

end


if CLIENT then
	function TOOL:DrawHUD()

		if not self:GetClientBool( "tooltip_enabled" ) then return end

		local ply = self:GetOwner()
		local tcg = self:GetClientNumber( "trace_col_group" )

		local trace = getCustomTrace( ply, tcg ) -- custom trace mostly detects more entities than player's eye trace
		local ent = trace.Entity

		if not ( ent:IsValid() or ent:IsWorld() ) then return end

		local pos = ( ent:GetPos() + ent:OBBCenter() ):ToScreen()
		local x, y = pos.x, pos.y - 15
		
		local col_group = ent:GetCollisionGroup()
		local olcol = HSVToColor( 50 + 16*col_group, 1, 0.5 )
		local bgcol = HSVToColor( 50 + 16*col_group, 0.75, 0.9 )
		olcol.a = 200
		bgcol.a = 200
		local font  = "GModWorldtip"
		local rad   = 8
		
		local text = ( "%s (%s)" ):format( colEnums[ col_group ], col_group )
		
		surface.SetFont( font )
		local tw, th = surface.GetTextSize( text )
		
		draw.RoundedBox( rad, x - tw/2 - 12, y - th/2 - 4, tw + 24, th + 8, olcol )
		draw.RoundedBox( rad, x - tw/2 - 10, y - th/2 - 2, tw + 20, th + 4, bgcol )
		draw.SimpleText( text, font, x, y, color_black, 1, 1 )
	end
end


local cvarlist = TOOL:BuildConVarList()

function TOOL.BuildCPanel( cPanel )

	local function paint( panel, w, h )
		local topHeight = panel:GetHeaderHeight()
		local c = not panel:GetExpanded()
		draw.RoundedBoxEx( 4, 0, 0, w, topHeight, Color( 50, 100, 200 ), true, true, c, c )
		draw.RoundedBoxEx( 8, 0, topHeight, w, h - topHeight + 5, Color( 240, 240, 240 ), false, false, true, true )
	end

	cPanel:Help( "tool."..mode..".desc" )

	cPanel:ToolPresets( mode, cvarlist )

	local cgComboBox, label = cPanel:ComboBox( "Collision Group:", mode.."_col_group" )
		cgComboBox:SetSortItems( false )
		cgComboBox:Dock( TOP )
		cgComboBox:DockMargin( 0, 20, 0, 0 )
		label:DockMargin( 0, 20, 0, 0 )
		for data, value in pairs( colEnums ) do
			cgComboBox:AddChoice( data..": "..value, data )
		end
		cPanel:ControlHelp( "The collision group to apply to the entity.\n" )

	local checkBox = cPanel:CheckBox( "Remove world no-collide on reload", mode.."_remove_constr" )
		cPanel:ControlHelp( "Remove any no-collide constraint that the entity has with the world on reload.\n" )

	local expForm = vgui.Create( "DForm", cPanel )
		cPanel:AddItem( expForm )
		expForm:SetExpanded( false )
		expForm:SetLabel( "Experimental" )
		expForm:SetPaintBackground( false )
		expForm:DockPadding( 0, 0, 0, 5 )
		function expForm:Paint(w, h)
			paint( self, w, h )
		end

		local tcgComboBox = expForm:ComboBox( "Trace C. Group:", mode.."_trace_col_group" )
			tcgComboBox:SetSortItems( false )
			tcgComboBox:Dock( TOP )
			for k, group in ipairs( { 0, 7, 9 } ) do
				tcgComboBox:AddChoice( group..": "..colEnums[group], group )
			end
			expForm:ControlHelp( "\nThe collision group that the tool's trace uses. Useful if the unmodified trace doesn't detect a specific collision group.\n- Group 7 (Vehicle) can hit group 12 (Vehicle Clip)\n- Group 9 (NPC) can hit group 14 (Door Blocker)" )
		
	local helpForm = vgui.Create( "DForm", cPanel )
		cPanel:AddItem( helpForm )
		helpForm:SetExpanded( true )
		helpForm:SetLabel( "Help" )
		helpForm:SetPaintBackground( false )
		helpForm:DockPadding( 0, 0, 0, 5 )
		function helpForm:Paint(w, h)
			paint( self, w, h )
		end

		local valveButton, fpButton = vgui.Create( "DButton", helpForm ), vgui.Create( "DButton", helpForm )
			valveButton:SetText( "Collision groups (Valve Wiki)" )
			fpButton:SetText( "Collision groups (Facepunch Wiki)" )

			valveButton:SetImage( "games/16/hl2.png" )
			fpButton:SetImage( "games/16/garrysmod.png" )
			
			function valveButton:DoClick() gui.OpenURL( "https://developer.valvesoftware.com/wiki/Collision_groups" ) end
			function fpButton:DoClick() gui.OpenURL( "https://wiki.facepunch.com/gmod/Enums/COLLISION_GROUP" ) end

			helpForm:AddItem( valveButton )
			helpForm:AddItem( fpButton )
	
		local tooltipCheckBox = helpForm:CheckBox( "Enable Tooltips", mode.."_tooltip_enabled" )
			tooltipCheckBox:SetToolTip( "Show a tooltip when pointing something with the tool." )


end