#pragma once

#include <godot_cpp/classes/character_body2d.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/vector2.hpp>

namespace godot {

class PlayerController : public CharacterBody2D {
	GDCLASS(PlayerController, CharacterBody2D)

private:
	float speed = 220.0f;
	Vector2 move_input = Vector2();

protected:
	static void _bind_methods();

public:
	PlayerController() = default;
	~PlayerController() = default;

	void set_speed(float p_speed);
	float get_speed() const;

	void set_move_input(Vector2 p_input);
	Vector2 get_move_input() const;

	void move_with_input(Vector2 p_input, double p_delta);
	void _physics_process(double p_delta);
};

}
