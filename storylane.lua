JSON = (loadfile "JSON.lua")()

read_file = function(file)
  if file then
    local f = io.open(file)
    local data = f:read("*all")
    f:close()
    return data
  else
    return ""
  end
end

local url_count = 0
local user_data = {}

write_user_data = function()
  local filename = os.getenv("USER_DATA_FILENAME")
  if filename then
    local f = io.open(filename, "w")
    f:write(JSON:encode(user_data).."\n")
    f:close()
  end
end

wget.callbacks.get_urls = function(file, url, is_css, iri)
  -- progress message
  url_count = url_count + 1
  if url_count % 10 == 0 then
    io.stdout:write("\r - Downloaded "..url_count.." URLs")
    io.stdout:flush()
  end

  local urls = {}
  local html = nil

  -- a web page: scan for usernames
  if string.match(url, "^http://www%.storylane%.com/") then
    html = read_file(file)

    if not user_data["next_users"] then
      user_data["next_users"] = {}
    end

    for username in string.gmatch(html, "class=\"avatar\" href=\"http://www%.storylane%.com/([-_a-zA-Z0-9]+)\"") do
      table.insert(user_data["next_users"], username)
    end

    write_user_data()
  end

  -- main user page
  local username = string.match(url, "^http://www%.storylane%.com/([-_a-zA-Z0-9]+)$")
  if username then
    user_data["username"] = username

    -- capture user's name
    local user_fullname = string.match(html, "\"og:title\" content=\"([^\"]+)\"")
    if user_fullname then
      user_data["fullname"] = user_fullname
    end

    write_user_data()

    if not string.match(html, "/images/error_bg.jpg") then
      -- proceed to subpages
      subpath = string.match(html, "\"(/profile/storylanes/[0-9]+/[-_a-zA-Z0-9]+)\"")
      if subpath then
        table.insert(urls, { url=("http://www.storylane.com"..subpath), link_expect_html=1 })
      end
      subpath = string.match(html, "\"(/following/[0-9]+/[-_a-zA-Z0-9]+)\"")
      if subpath then
        table.insert(urls, { url=("http://www.storylane.com"..subpath), link_expect_html=1 })
      end
      subpath = string.match(html, "\"(/followers/[0-9]+/[-_a-zA-Z0-9]+)\"")
      if subpath then
        table.insert(urls, { url=("http://www.storylane.com"..subpath), link_expect_html=1 })
      end

      -- permalink
      perma = string.match(html, "content=\"(http://www%.storylane%.com/profile/perma/[0-9]+/[-_a-zA-Z0-9]+)\"")
      if perma then
        table.insert(urls, { url=perma, link_expect_html=1 })
      end

      -- stories that user X'ed
      for i,verb in pairs({"liked","funny","inspiredby","movedby","hugged","fbshares","twshares","agreed","disagreed","wants","impressedby","hasbeenthere"}) do
        table.insert(urls, { url=(url.."/"..verb), link_expect_html=1 })
      end

      -- stories!
      for story_url in string.gmatch(html, "href=\"(http://www%.storylane%.com/stories/show/[0-9]+/[-_a-zA-Z0-9]+)\"") do
        table.insert(urls, { url=story_url, link_expect_html=1 })
      end
    end
  end

  return urls
end

