function init()
  local sound = config.getParameter("sound")
  if sound then pane.playSound(sound) end
  pane.dismiss()
end
