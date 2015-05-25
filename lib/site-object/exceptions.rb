module SiteObjectExceptions
  class BrowserLibraryNotSupportedError < RuntimeError
  end

  class PageInitError                   < RuntimeError
  end

  class PageNavigationError             < RuntimeError
  end

  class PageNavigationNotAllowedError   < RuntimeError
  end

  class SiteInitError                   < RuntimeError
  end

  class WrongPageError                  < RuntimeError
  end
end # SiteObjectExceptions
