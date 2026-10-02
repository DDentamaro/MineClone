class_name MocapMoves
extends RefCounted
## Pose chiave ricavate dai video di riferimento generati con Higgsfield (D-046):
## tools/mocap (extract_pose.py -> keyframes.py -> fit_poses.gd -> emit_gd.py).
## File generato: non modificare a mano. Gradi [x, y, z] per osso come in
## WeaponLibrary; "time" = [preparazione, colpo, ritorno] misurati nel video (s).

const MOVES := {
	"sword_cross": {
		"time": [0.167, 0.250, 0.250],
		"wind": {"chest": [-16, 7, -2], "arm_r": [45, 76, 66], "fore_r": [59, 0, 0], "arm_l": [63, -53, -65], "fore_l": [49, 0, 0], "hand_r": [-120, 0, 0], "head": [0, -4, 0]},
		"strike": {"chest": [-9, -7, 5], "arm_r": [47, 37, 80], "fore_r": [16, 0, 0], "arm_l": [60, -32, -62], "fore_l": [37, 0, 0], "hand_r": [-100, 0, 0], "head": [0, 4, 0]},
		"follow": {"chest": [-5, -4, 7], "arm_r": [20, 31, 80], "fore_r": [21, 0, 0], "arm_l": [60, -34, -62], "fore_l": [33, 0, 0], "hand_r": [-100, 0, 0], "head": [0, 2, 0]},
	},
	"sword_leap": {
		"time": [0.125, 0.250, 0.167],
		"wind": {"chest": [-10, 9, 15], "arm_r": [39, 74, 141], "fore_r": [13, 0, 0], "arm_l": [108, -53, -121], "fore_l": [-3, 0, 0], "hand_r": [-100, 0, 0], "head": [0, -5, 0]},
		"strike": {"chest": [-50, 9, 15], "arm_r": [56, 133, 123], "fore_r": [19, 0, 0], "arm_l": [180, -71, -130], "fore_l": [-23, 0, 0], "hand_r": [-80, 0, 0], "head": [0, -5, 0]},
		"follow": {"chest": [-41, 32, 0], "arm_r": [92, 115, 126], "fore_r": [28, 0, 0], "arm_l": [171, 28, -126], "fore_l": [-64, 0, 0], "hand_r": [-80, 0, 0], "head": [0, -19, 0]},
	},
	"hammer_smash": {
		"time": [0.792, 0.333, 0.500],
		"wind": {"chest": [-36, -6, 8], "arm_r": [54, 136, 148], "fore_r": [68, 0, 0], "arm_l": [60, -114, -103], "fore_l": [69, 0, 0], "hand_r": [-130, 0, 0], "head": [0, 3, 0]},
		"strike": {"chest": [-50, 0, 15], "arm_r": [108, 180, 159], "fore_r": [56, 0, 0], "arm_l": [125, -180, -162], "fore_l": [20, 0, 0], "hand_r": [-80, 0, 0], "head": [0, 0, 0]},
		"follow": {"chest": [-50, -15, 15], "arm_r": [108, 180, 161], "fore_r": [56, 0, 0], "arm_l": [125, -180, -173], "fore_l": [20, 0, 0], "hand_r": [-80, 0, 0], "head": [0, 9, 0]},
	},
}
