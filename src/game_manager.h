#pragma once

#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/string.hpp>

namespace godot {

class GameManager : public Node {
	GDCLASS(GameManager, Node)

private:
	int score = 0;
	String team_name = "Coursework Team";

protected:
	static void _bind_methods();

public:
	GameManager() = default;
	~GameManager() = default;

	void set_team_name(const String &p_team_name);
	String get_team_name() const;

	void set_score(int p_score);
	int get_score() const;

	void add_score(int p_delta);
	String get_status_text() const;
};

}
