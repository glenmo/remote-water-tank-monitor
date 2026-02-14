// LoRa Tank Node Enclosure - Field-ready concept (v3)
// Fixes:
// - Removes lid locator pins/sockets (no floating pins)
// - Replaces snap "catch blocks" with proper snap slots (windows) in base walls
// - Snap tabs on lid latch into those slots
// - Snap positions moved to avoid power socket / USB cutouts
//
// Units: mm
// OpenSCAD: F6 (Render) then Export STL

$fn = 96;

// ------------------------
// Main parameters
// ------------------------
L = 160;
W = 110;
H = 60;

wall  = 3;
floor = 3;

base_h = 35;
lid_h  = H - base_h;

// Lid overlap
overlap_depth = 12;
lid_skirt_t   = 2;
lid_top_t     = 3;

// ------------------------
// Cutouts
// ------------------------
USB_HOLE_D  = 24.2;   // USB-C bulkhead hole clearance (nominal 24.0)
PWR_HOLE_D  = 12.2;   // M12 gland clearance (adjust to suit)
SMA_HOLE_D  = 6.5;    // SMA bulkhead hole
SMA_FLAT_TO = 6.0;    // D-hole flat-to (flat plane at +3.0 from centre)

// Cutout locations (front face is y=0)
usb_center_x   = 120;
pwr_center_x   = 25;
front_center_z = 18;

// SMA on right face (x=L)
sma_center_y = W - wall - 6;
sma_center_z = base_h - 18;

// ------------------------
// Options (toggles)
// ------------------------
SHOW_BASE = true;
SHOW_LID  = true;

USE_SCREWS    = true;  // M3 stainless recommended
USE_SNAPS     = true;  // snap tabs + base slots
USE_ORING     = true;  // O-ring groove on lid underside
USE_POLEMOUNT = true;  // pole-mount lugs on base

// ------------------------
// Screw boss parameters (M3)
// ------------------------
SCREW_CLEAR_D = 3.4;
SCREW_PILOT_D = 2.7;     // adjust for heat-set insert
BOSS_OD = 8.5;
BOSS_H  = 10.0;
LID_COUNTERBORE_D = 6.4;
LID_COUNTERBORE_DEPTH = 2.2;
BOSS_EDGE_OFFSET = 12.0;

// ------------------------
// O-ring groove (rectangular ring groove)
// ------------------------
ORING_GROOVE_W = 2.7;
ORING_GROOVE_D = 1.7;
ORING_INSET = 6.0;

// ------------------------
// Pole-mount lugs
// ------------------------
POLE_LUG_THICK = 6.0;
POLE_LUG_W     = 20.0;
POLE_LUG_H     = 18.0;
POLE_LUG_SPAN  = 55.0;
POLE_HOLE_D    = 6.5;
POLE_HOLE_Z    = 18.0;

// ------------------------
// Snap slot + tab parameters (PETG/Qidi PTG Tough friendly)
// ------------------------
SNAP_X1 = 70;    // moved away from power (x=25) and USB (x=120)
SNAP_X2 = 145;

SNAP_Z  = 24;    // height of slot centre above floor (tune)
SNAP_SLOT_W = 12.5;
SNAP_SLOT_H = 4.5;

// Slot should fully cut through wall thickness
SNAP_SLOT_DEPTH = wall + 2;

// Lid snap tab (external) - latches into slot
SNAP_TAB_W = 13.5;      // slightly wider than slot (but will flex)
SNAP_TAB_T = 2.4;
SNAP_TAB_L = 18.0;
SNAP_HOOK_H = 2.4;      // hook height engaging slot
SNAP_HOOK_LIP = 1.2;
SNAP_CLEAR = 0.35;      // clearance for PETG

// ------------------------
// Helpers
// ------------------------
module d_hole_cutter(h, d, flat_to){
    r = d/2;
    flat_y = flat_to/2;
    difference(){
        rotate([0, 90, 0]) cylinder(h=h, r=r, center=true);
        translate([0, flat_y + 50, 0]) cube([h + 2, 100, 200], center=true);
    }
}

module tray_base_shell(){
    union(){
        cube([L, W, floor], center=false);

        translate([0, 0, floor])            cube([wall, W, base_h - floor], center=false);
        translate([L - wall, 0, floor])     cube([wall, W, base_h - floor], center=false);
        translate([wall, 0, floor])         cube([L - 2*wall, wall, base_h - floor], center=false);
        translate([wall, W - wall, floor])  cube([L - 2*wall, wall, base_h - floor], center=false);
    }
}

module screw_bosses_base(){
    boss_r = BOSS_OD/2;
    for (pt = [
        [BOSS_EDGE_OFFSET, BOSS_EDGE_OFFSET],
        [L - BOSS_EDGE_OFFSET, BOSS_EDGE_OFFSET],
        [BOSS_EDGE_OFFSET, W - BOSS_EDGE_OFFSET],
        [L - BOSS_EDGE_OFFSET, W - BOSS_EDGE_OFFSET]
    ]){
        translate([pt[0], pt[1], floor])
            cylinder(h=BOSS_H, r=boss_r, center=false);
    }
}

module screw_pilots_base(){
    for (pt = [
        [BOSS_EDGE_OFFSET, BOSS_EDGE_OFFSET],
        [L - BOSS_EDGE_OFFSET, BOSS_EDGE_OFFSET],
        [BOSS_EDGE_OFFSET, W - BOSS_EDGE_OFFSET],
        [L - BOSS_EDGE_OFFSET, W - BOSS_EDGE_OFFSET]
    ]){
        translate([pt[0], pt[1], floor + BOSS_H/2])
            cylinder(h=BOSS_H + 2, d=SCREW_PILOT_D, center=true);
    }
}

module pole_mount_lugs(){
    // Two lugs on back face (y = W) for hose clamp or U-bolt
    lug_x = L/2;
    y0 = W; // back outer face
    z0 = floor + 6;

    for (dy = [-POLE_LUG_SPAN/2, POLE_LUG_SPAN/2]){
        translate([lug_x, y0 + POLE_LUG_THICK/2, z0])
            cube([POLE_LUG_W, POLE_LUG_THICK, POLE_LUG_H], center=true);

        translate([lug_x, y0 + POLE_LUG_THICK/2, POLE_HOLE_Z])
            rotate([90,0,0])
                cylinder(h=POLE_LUG_THICK + 2, d=POLE_HOLE_D, center=true);
    }
}

module snap_slots_base(){
    // Rectangular windows cut into front and back walls
    for (xpos = [SNAP_X1, SNAP_X2]){
        // front wall (y ~ wall/2)
        translate([xpos, wall/2, SNAP_Z])
            cube([SNAP_SLOT_W, SNAP_SLOT_DEPTH, SNAP_SLOT_H], center=true);

        // back wall (y ~ W-wall/2)
        translate([xpos, W - wall/2, SNAP_Z])
            cube([SNAP_SLOT_W, SNAP_SLOT_DEPTH, SNAP_SLOT_H], center=true);
    }
}

// ------------------------
// Base with all features
// ------------------------
module base_with_features(){
    difference(){
        union(){
            tray_base_shell();
            if (USE_SCREWS) screw_bosses_base();
            if (USE_POLEMOUNT) pole_mount_lugs();
        }

        // Cutouts on front wall
        translate([usb_center_x, wall/2, front_center_z])
            rotate([90,0,0]) cylinder(h=wall + 4, d=USB_HOLE_D, center=true);

        translate([pwr_center_x, wall/2, front_center_z])
            rotate([90,0,0]) cylinder(h=wall + 4, d=PWR_HOLE_D, center=true);

        // SMA D-hole on right wall
        translate([L - wall/2, sma_center_y, sma_center_z])
            d_hole_cutter(wall + 4, SMA_HOLE_D, SMA_FLAT_TO);

        // Screw pilots in bosses
        if (USE_SCREWS) screw_pilots_base();

        // Snap slots
        if (USE_SNAPS) snap_slots_base();
    }
}

// ------------------------
// Lid geometry
// ------------------------
module lid_shell(){
    z_top = base_h + lid_h;
    z_plate_bottom = z_top - lid_top_t;
    z_skirt_bottom = z_plate_bottom - overlap_depth;

    union(){
        // top plate
        translate([0, 0, z_plate_bottom]) cube([L, W, lid_top_t], center=false);

        // skirt walls
        translate([0, 0, z_skirt_bottom]) cube([lid_skirt_t, W, overlap_depth], center=false);
        translate([L - lid_skirt_t, 0, z_skirt_bottom]) cube([lid_skirt_t, W, overlap_depth], center=false);
        translate([lid_skirt_t, 0, z_skirt_bottom]) cube([L - 2*lid_skirt_t, lid_skirt_t, overlap_depth], center=false);
        translate([lid_skirt_t, W - lid_skirt_t, z_skirt_bottom]) cube([L - 2*lid_skirt_t, lid_skirt_t, overlap_depth], center=false);
    }
}

module oring_groove(){
    z_top = base_h + lid_h;
    z_plate_bottom = z_top - lid_top_t;

    outer_x = L - 2*ORING_INSET;
    outer_y = W - 2*ORING_INSET;
    inner_x = outer_x - 2*ORING_GROOVE_W;
    inner_y = outer_y - 2*ORING_GROOVE_W;

    difference(){
        translate([ORING_INSET, ORING_INSET, z_plate_bottom])
            cube([outer_x, outer_y, ORING_GROOVE_D], center=false);

        translate([ORING_INSET + ORING_GROOVE_W, ORING_INSET + ORING_GROOVE_W, z_plate_bottom - 0.1])
            cube([inner_x, inner_y, ORING_GROOVE_D + 0.2], center=false);
    }
}

module lid_screw_clearance_and_counterbore(){
    z_top = base_h + lid_h;
    for (pt = [
        [BOSS_EDGE_OFFSET, BOSS_EDGE_OFFSET],
        [L - BOSS_EDGE_OFFSET, BOSS_EDGE_OFFSET],
        [BOSS_EDGE_OFFSET, W - BOSS_EDGE_OFFSET],
        [L - BOSS_EDGE_OFFSET, W - BOSS_EDGE_OFFSET]
    ]){
        // through clearance
        translate([pt[0], pt[1], z_top - lid_top_t/2])
            cylinder(h=lid_top_t + 2, d=SCREW_CLEAR_D, center=true);

        // counterbore from top
        translate([pt[0], pt[1], z_top - LID_COUNTERBORE_DEPTH/2])
            cylinder(h=LID_COUNTERBORE_DEPTH + 0.2, d=LID_COUNTERBORE_D, center=true);
    }
}

module snap_tab_lid(direction){
    // direction: +1 for front (points -Y), -1 for back (points +Y after rotation)
    // Tab is external and hooks into the base slot.
    // Tab is attached to the outside of the skirt.
    union(){
        // tab body (vertical)
        cube([SNAP_TAB_W, SNAP_TAB_T, SNAP_TAB_L], center=false);

        // hook lip at free end
        translate([0, 0, SNAP_TAB_L - SNAP_HOOK_H])
            cube([SNAP_TAB_W, SNAP_TAB_T + SNAP_HOOK_LIP, SNAP_HOOK_H], center=false);
    }
}

module snap_tabs_lid(){
    // Place tabs aligned to slots on base front/back walls.
    z_top = base_h + lid_h;
    z_plate_bottom = z_top - lid_top_t;
    z_skirt_bottom = z_plate_bottom - overlap_depth;

    // Set tab top so hook aligns to SNAP_Z
    tab_z0 = (SNAP_Z + SNAP_SLOT_H/2) - SNAP_TAB_L + 1.0;

    for (xpos = [SNAP_X1, SNAP_X2]){
        // Front wall tab (outside front face, y negative)
        translate([xpos - SNAP_TAB_W/2, -SNAP_TAB_T - 0.5, tab_z0])
            snap_tab_lid(1);

        // Back wall tab (outside back face, y beyond W)
        translate([xpos - SNAP_TAB_W/2, W + 0.5, tab_z0])
            rotate([0,0,180])
                snap_tab_lid(-1);
    }
}

module lid_with_features(){
    difference(){
        union(){
            lid_shell();
            if (USE_SNAPS) snap_tabs_lid();
        }

        if (USE_ORING) oring_groove();
        if (USE_SCREWS) lid_screw_clearance_and_counterbore();

        // Provide relief in lid skirt where snap tabs pass (so skirt doesn't collide)
        // Cut small windows in skirt directly behind each tab location
        if (USE_SNAPS){
            for (xpos = [SNAP_X1, SNAP_X2]){
                // front relief
                translate([xpos, lid_skirt_t/2, SNAP_Z])
                    cube([SNAP_SLOT_W + 4, lid_skirt_t + 2, SNAP_SLOT_H + 6], center=true);
                // back relief
                translate([xpos, W - lid_skirt_t/2, SNAP_Z])
                    cube([SNAP_SLOT_W + 4, lid_skirt_t + 2, SNAP_SLOT_H + 6], center=true);
            }
        }
    }
}

// ------------------------
// Scene
// ------------------------
if (SHOW_BASE){
    color("lightgray") base_with_features();
}

if (SHOW_LID){
    color("gainsboro") lid_with_features();
}
