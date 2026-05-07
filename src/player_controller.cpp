#include "player_controller.h"

using namespace godot;

void PlayerController::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_speed", "speed"), &PlayerController::set_speed);
	ClassDB::bind_method(D_METHOD("get_speed"), &PlayerController::get_speed);
	ClassDB::bind_method(D_METHOD("set_move_input", "input"), &PlayerController::set_move_input);
	ClassDB::bind_method(D_METHOD("get_move_input"), &PlayerController::get_move_input);
	ClassDB::bind_method(D_METHOD("move_with_input", "input", "delta"), &PlayerController::move_with_input);

	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "speed"), "set_speed", "get_speed");
	ADD_PROPERTY(PropertyInfo(Variant::VECTOR2, "move_input"), "set_move_input", "get_move_input");
}

void PlayerController::set_speed(float p_speed) {
	speed = p_speed;
}

float PlayerController::get_speed() const {
	return speed;
}

void PlayerController::set_move_input(Vector2 p_input) {
	move_input = p_input;
}

Vector2 PlayerController::get_move_input() const {
	return move_input;
}

void PlayerController::move_with_input(Vector2 p_input, double p_delta) {
	Vector2 normalized = p_input;
	if (normalized.length() > 1.0f) {
		normalized = normalized.normalized();
	}

	set_velocity(normalized * speed);
	move_and_slide();
	set_position(get_position() + get_velocity() * (float)p_delta);
}

void PlayerController::_physics_process(double p_delta) {
	move_with_input(move_input, p_delta);
}
