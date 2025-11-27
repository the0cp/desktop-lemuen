#include "taskbar_hider.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/classes/display_server.hpp>
#include <godot_cpp/classes/window.hpp>
#include <godot_cpp/classes/engine.hpp>

#define WIN32_LEAN_AND_MEAN
#include <windows.h>

using namespace godot;

void TaskbarHider::_bind_methods() {
	ClassDB::bind_method(D_METHOD("enforce_tool_window_style"), &TaskbarHider::enforce_tool_window_style);
}

TaskbarHider::TaskbarHider() {
	time_accumulator = 0.0;
}

TaskbarHider::~TaskbarHider() {
}

void TaskbarHider::_process(double delta) {
	if (Engine::get_singleton()->is_editor_hint()) {
		return;
	}

	time_accumulator += delta;
	if (time_accumulator > 0.5) {
		enforce_tool_window_style();
		time_accumulator = 0.0;
	}
}

void TaskbarHider::enforce_tool_window_style() {
	if (Engine::get_singleton()->is_editor_hint()) {
		return;
	}

	DisplayServer *ds = DisplayServer::get_singleton();
	if (!ds) return;

	int64_t handle_id = ds->window_get_native_handle(DisplayServer::WINDOW_HANDLE);
	HWND hwnd = (HWND)handle_id;

	if (hwnd == NULL) return;

	LONG_PTR current_style = GetWindowLongPtr(hwnd, GWL_EXSTYLE);

	if ((current_style & WS_EX_APPWINDOW) != 0 || (current_style & WS_EX_TOOLWINDOW) == 0) {
		ShowWindow(hwnd, SW_HIDE);

		current_style &= ~WS_EX_APPWINDOW;
		current_style |= WS_EX_TOOLWINDOW;

		SetWindowLongPtr(hwnd, GWL_EXSTYLE, current_style);

		ShowWindow(hwnd, SW_SHOW);
	}
}