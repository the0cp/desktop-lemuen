using Godot;
using System;
using System.Runtime.InteropServices;

public partial class TaskbarHider : Node
{
	[DllImport("user32.dll", EntryPoint = "GetWindowLongPtr")]
	private static extern IntPtr GetWindowLongPtr(IntPtr hWnd, int nIndex);

	[DllImport("user32.dll", EntryPoint = "SetWindowLongPtr")]
	private static extern IntPtr SetWindowLongPtr(IntPtr hWnd, int nIndex, IntPtr dwNewLong);

	[DllImport("user32.dll")]
	private static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

	private const int GWL_EXSTYLE = -20;
	private const int WS_EX_TOOLWINDOW = 0x00000080;
	private const int WS_EX_APPWINDOW = 0x00040000;

	private const int SW_HIDE = 0;
	private const int SW_SHOW = 5;

	public override void _Ready()
	{
		if (OS.GetName() != "Windows") return;
		CallDeferred(nameof(EnforceToolWindowStyle));
		var timer = GetTree().CreateTimer(0.5);
		timer.Timeout += OnCheckTimerTimeout;
	}

	private void OnCheckTimerTimeout()
	{
		EnforceToolWindowStyle();
		GetTree().CreateTimer(0.5).Timeout += OnCheckTimerTimeout;
	}

	public void EnforceToolWindowStyle()
	{
		long hwndId = DisplayServer.WindowGetNativeHandle(DisplayServer.HandleType.WindowHandle);
		IntPtr hWnd = new IntPtr(hwndId);

		if (hWnd == IntPtr.Zero) return;

		long currentStyle = GetWindowLongPtr(hWnd, GWL_EXSTYLE).ToInt64();

		if ((currentStyle & WS_EX_APPWINDOW) != 0 || (currentStyle & WS_EX_TOOLWINDOW) == 0)
		{
			ShowWindow(hWnd, SW_HIDE);

			currentStyle &= ~WS_EX_APPWINDOW;
			currentStyle |= WS_EX_TOOLWINDOW;

			SetWindowLongPtr(hWnd, GWL_EXSTYLE, new IntPtr(currentStyle));

			ShowWindow(hWnd, SW_SHOW);
		}
	}
}
