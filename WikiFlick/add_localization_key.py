import os

# Base directory containing .lproj folders
base_dir = "/Users/sefacemturan/WikiShorts/WikiFlick"

# The key to add
key = "continue_without_pro"

# Translations for the key
translations = {
    "en": "Continue without WikiShorts Pro",
    "tr": "WikiShorts Pro olmadan devam et",
    "es": "Continuar sin WikiShorts Pro",
    "fr": "Continuer sans WikiShorts Pro",
    "de": "Weiter ohne WikiShorts Pro",
    "it": "Continua senza WikiShorts Pro",
    "pt": "Continuar sem WikiShorts Pro",
    "ru": "Продолжить без WikiShorts Pro",
    "ja": "WikiShorts Proなしで続行",
    "ko": "WikiShorts Pro 없이 계속",
    "zh": "继续而不使用 WikiShorts Pro",
    "ar": "الاستمرار بدون WikiShorts Pro",
    "hi": "WikiShorts Pro के बिना जारी रखें",
    "nl": "Doorgaan zonder WikiShorts Pro",
    "sv": "Fortsätt utan WikiShorts Pro",
    "no": "Fortsett uten WikiShorts Pro",
    "da": "Fortsæt uden WikiShorts Pro",
    "fi": "Jatka ilman WikiShorts Pro:ta",
    "pl": "Kontynuuj bez WikiShorts Pro",
    "el": "Συνέχεια χωρίς WikiShorts Pro",
    "he": "המשך ללא WikiShorts Pro",
    "id": "Lanjutkan tanpa WikiShorts Pro",
    "ms": "Teruskan tanpa WikiShorts Pro",
    "th": "ดำเนินการต่อโดยไม่มี WikiShorts Pro",
    "vi": "Tiếp tục mà không có WikiShorts Pro",
    "cs": "Pokračovat bez WikiShorts Pro",
    "hu": "Folytatás WikiShorts Pro nélkül",
    "ro": "Continuă fără WikiShorts Pro",
    "uk": "Продовжити без WikiShorts Pro",
    "hr": "Nastavi bez WikiShorts Pro",
    "sk": "Pokračovať bez WikiShorts Pro",
    "bg": "Продължи без WikiShorts Pro",
    "sr": "Настави без WikiShorts Pro",
    "ca": "Continua sense WikiShorts Pro",
    "lt": "Tęsti be WikiShorts Pro",
    "sl": "Nadaljuj brez WikiShorts Pro",
    "et": "Jätka ilma WikiShorts Prota",
    "lv": "Turpināt bez WikiShorts Pro"
}

# English fallback
fallback_translation = "Continue without WikiShorts Pro"

def update_localization_files():
    print("Starting localization update...")
    
    # Iterate through all items in the base directory
    count = 0
    for item in os.listdir(base_dir):
        if item.endswith(".lproj"):
            lang_code = item.split(".")[0]
            # Handle zh-Hans / zh-Hant logic if needed, simplify to prefix match or exact match
            # For simplicity, we use the translations dict directly or fallback
            
            # Map complex codes to simple ones if needed (e.g. pt-BR -> pt)
            simple_lang_code = lang_code.split("-")[0]
            
            translation = translations.get(lang_code) or translations.get(simple_lang_code) or fallback_translation
            
            file_path = os.path.join(base_dir, item, "Localizable.strings")
            
            if os.path.exists(file_path):
                try:
                    with open(file_path, "r", encoding="utf-8") as f:
                        content = f.read()
                    
                    # Check if key already exists
                    if f'"{key}"' in content:
                        # Replace existing
                        lines = content.splitlines()
                        new_lines = []
                        for line in lines:
                            if line.strip().startswith(f'"{key}"'):
                                new_lines.append(f'"{key}" = "{translation}";')
                            else:
                                new_lines.append(line)
                        new_content = "\n".join(new_lines)
                        if new_content != content: # Only write if changed
                             with open(file_path, "w", encoding="utf-8") as f:
                                f.write(new_content)
                             print(f"Updated {lang_code}: {translation}")
                        else:
                             print(f"Skipped {lang_code}: Already correct")

                    else:
                        # Append new key
                        if not content.endswith("\n"):
                            content += "\n"
                        content += f'\n"{key}" = "{translation}";\n'
                        
                        with open(file_path, "w", encoding="utf-8") as f:
                            f.write(content)
                        print(f"Added to {lang_code}: {translation}")
                    
                    count += 1
                except Exception as e:
                    print(f"Error processing {lang_code}: {e}")
    
    print(f"Finished updating {count} language files.")

if __name__ == "__main__":
    update_localization_files()
