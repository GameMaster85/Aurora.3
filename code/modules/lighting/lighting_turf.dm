/turf
	var/dynamic_lighting = TRUE
	luminosity           = 1

	var/tmp/lighting_corners_initialised = FALSE

	var/tmp/list/datum/light_source/affecting_lights       // List of light sources affecting this turf.
	var/tmp/atom/movable/lighting_overlay/lighting_overlay // Our lighting overlay.
	var/tmp/list/datum/lighting_corner/corners
	var/tmp/has_opaque_atom = FALSE // Not to be confused with opacity, this will be TRUE if there's any opaque atom on the tile.

/turf/New()
	. = ..()

	if (opacity)
		has_opaque_atom = TRUE

// Causes any affecting light sources to be queued for a visibility update, for example a door got opened.
/turf/proc/reconsider_lights()
	L_PROF(src, "turf_reconsider")
	for (var/datum/light_source/L in affecting_lights)
		L.vis_update()

// Forces a lighting update. Reconsider lights is preferred when possible.
/turf/proc/force_update_lights()
	L_PROF(src, "turf_forceupdate")
	for (var/datum/light_source/L in affecting_lights)
		L.force_update()

/turf/proc/lighting_clear_overlay()
	if (lighting_overlay)
		returnToPool(lighting_overlay)

	L_PROF(src, "turf_clear_overlay")

	for (var/datum/lighting_corner/C in corners)
		C.update_active()

// Builds a lighting overlay for us, but only if our area is dynamic.
/turf/proc/lighting_build_overlay()
	if (lighting_overlay)
		return

	L_PROF(src, "turf_build_overlay")

	var/area/A = loc
	if (A.dynamic_lighting && dynamic_lighting)
		if (!lighting_corners_initialised || !corners)
			generate_missing_corners()

		new /atom/movable/lighting_overlay(src)

		for (var/datum/lighting_corner/C in corners)
			if (!C.active) // We would activate the corner, calculate the lighting for it.
				for (var/L in C.affecting)
					var/datum/light_source/S = L
					S.recalc_corner(C, TRUE)

				C.active = TRUE

#define SCALE(targ,min,max) (targ - min) / (max - min)

// Used to get a scaled lumcount.
/turf/proc/get_lumcount(minlum = 0, maxlum = 1)
	if (!lighting_overlay)
		return 0.5

	var/totallums = 0
	for (var/datum/lighting_corner/L in corners)
		totallums += L.lum_r + L.lum_b + L.lum_g

	totallums /= 12 // 4 corners, each with 3 channels, get the average.

	totallums = SCALE(totallums, minlum, maxlum)

	return CLAMP01(totallums)

// Gets the current UV illumination of the turf. Always 100% for space & other static-lit tiles.
/turf/proc/get_uv_lumcount(minlum = 0, maxlum = 1)
	if (!lighting_overlay)
		return 1

	L_PROF(src, "turf_get_uv")

	var/totallums = 0
	for (var/datum/lighting_corner/L in corners)
		totallums += L.lum_u

	totallums /= 4	// average of four corners.

	totallums = SCALE(totallums, minlum, maxlum)

	return CLAMP01(totallums)

#undef SCALE

// Can't think of a good name, this proc will recalculate the has_opaque_atom variable.
/turf/proc/recalc_atom_opacity()
	has_opaque_atom = FALSE
	for (var/atom/A in src.contents + src) // Loop through every movable atom on our tile PLUS ourselves (we matter too...)
		if (A.opacity)
			has_opaque_atom = TRUE
			return 	// No need to continue if we find something opaque.

// If an opaque movable atom moves around we need to potentially update visibility.
/turf/Entered(atom/movable/Obj, atom/OldLoc)
	. = ..()

	if (Obj && Obj.opacity)
		has_opaque_atom = TRUE // Make sure to do this before reconsider_lights(), incase we're on instant updates. Guaranteed to be on in this case.
		reconsider_lights()

/turf/Exited(atom/movable/Obj, atom/newloc)
	. = ..()

	if (Obj && Obj.opacity)
		recalc_atom_opacity() // Make sure to do this before reconsider_lights(), incase we're on instant updates.
		reconsider_lights()

/turf/change_area(area/old_area, area/new_area)
	if (new_area.dynamic_lighting != old_area.dynamic_lighting)
		if (new_area.dynamic_lighting)
			lighting_build_overlay()

		else
			lighting_clear_overlay()

/turf/proc/get_corners()
	if (has_opaque_atom)
		return null // Since this proc gets used in a for loop, null won't be looped though.

	return corners

/turf/proc/generate_missing_corners()
	lighting_corners_initialised = TRUE
	if (!corners)
		corners = list(null, null, null, null)

	for (var/i = 1 to 4)
		if (corners[i]) // Already have a corner on this direction.
			continue

		corners[i] = new/datum/lighting_corner(src, LIGHTING_CORNER_DIAGONAL[i])
