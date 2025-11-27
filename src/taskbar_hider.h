#ifndef TASKBAR_HIDER_H
#define TASKBAR_HIDER_H

#include <godot_cpp/classes/node.hpp>

namespace godot {

class TaskbarHider : public Node {
	GDCLASS(TaskbarHider, Node)

private:
	double time_accumulator;

protected:
	static void _bind_methods();

public:
	TaskbarHider();
	~TaskbarHider();

	void _process(double delta) override;
	void enforce_tool_window_style();
};

}

#endif