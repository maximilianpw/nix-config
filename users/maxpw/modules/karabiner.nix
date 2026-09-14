{
  isDarwin,
  lib,
  ...
}: {
  xdg.configFile."karabiner/karabiner.json" = lib.mkIf isDarwin {
    text = builtins.toJSON {
      global = {
        check_for_updates_on_startup = false;
        show_in_menu_bar = false;
      };
      profiles = [
        {
          name = "Default profile";
          selected = true;
          complex_modifications = {
            parameters = {
              "basic.to_if_alone_timeout_milliseconds" = 250;
            };
            rules = [
              {
                description = "Caps Lock held as Hyper, tapped as Escape";
                manipulators = [
                  {
                    type = "basic";
                    from = {
                      key_code = "caps_lock";
                      modifiers.optional = ["any"];
                    };
                    to = [
                      {
                        key_code = "left_shift";
                        modifiers = [
                          "left_command"
                          "left_control"
                          "left_option"
                        ];
                      }
                    ];
                    to_if_alone = [
                      {key_code = "escape";}
                    ];
                  }
                ];
              }
            ];
          };
          virtual_hid_keyboard.keyboard_type_v2 = "ansi";
        }
      ];
    };
  };
}
