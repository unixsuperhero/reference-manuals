-- Keep relative links intact while pointing Markdown documents at HTML exports.
function Link(link)
  local target = link.target
  if target:match("^https?://") or target:match("^mailto:") or target:match("^#") then
    return link
  end

  link.target = target:gsub("%.md([?#].*)$", ".html%1")
  link.target = link.target:gsub("%.md$", ".html")
  return link
end
