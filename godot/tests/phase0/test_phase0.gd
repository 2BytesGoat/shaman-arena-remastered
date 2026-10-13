extends GdUnitTestSuite

const EXTENSION_CLASSES := [
	"AttributeContainer",
	"AttributeSet",
	"Attribute",
	"AttributeBuff",
	"AttributeOperation",
	"AbilityContainer",
	"Ability",
	"RuntimeAbility",
]


func test_ggas_and_gga_classes_are_registered() -> void:
	for cls: String in EXTENSION_CLASSES:
		assert_bool(ClassDB.class_exists(cls)).is_true()


func test_project_version_is_current_m1_version() -> void:
	assert_str(str(ProjectSettings.get_setting("application/config/version"))).is_equal("0.1.0")


func test_per_player_actions_exist() -> void:
	for player: int in [0, 1]:
		for suffix: String in ["up", "down", "left", "right", "spell_0", "spell_1", "spell_2", "spell_3", "spell_4", "spell_5", "consumable_0", "consumable_1", "taunt", "ui_up", "ui_down", "ui_left", "ui_right", "ui_accept", "ui_cancel"]:
			var action := "player_%d_%s" % [player, suffix]
			assert_bool(InputMap.has_action(action)).is_true()