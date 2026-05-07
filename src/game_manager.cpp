#include "game_manager.h"

#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

void GameManager::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_team_name", "team_name"), &GameManager::set_team_name);
	ClassDB::bind_method(D_METHOD("get_team_name"), &GameManager::get_team_name);
	ClassDB::bind_method(D_METHOD("set_score", "score"), &GameManager::set_score);
	ClassDB::bind_method(D_METHOD("get_score"), &GameManager::get_score);
	ClassDB::bind_method(D_METHOD("add_score", "delta"), &GameManager::add_score);
	ClassDB::bind_method(D_METHOD("get_status_text"), &GameManager::get_status_text);

	ADD_PROPERTY(PropertyInfo(Variant::STRING, "team_name"), "set_team_name", "get_team_name");
	ADD_PROPERTY(PropertyInfo(Variant::INT, "score"), "set_score", "get_score");
}

void GameManager::set_team_name(const String &p_team_name) {
	team_name = p_team_name;
}

String GameManager::get_team_name() const {
	return team_name;
}

void GameManager::set_score(int p_score) {
	score = p_score;
}

int GameManager::get_score() const {
	return score;
}

void GameManager::add_score(int p_delta) {
	score += p_delta;
	UtilityFunctions::print("[GameManager] score = ", score);
}

String GameManager::get_status_text() const {
	return vformat("%s | score=%d", team_name, score);
}
