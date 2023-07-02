from googletrans import Translator

def translate_to_thai(text):
    translator = Translator()
    translation = translator.translate(text, dest='th')
    return translation.text

text_to_translate = "Hello, how are you?"
translated_text = translate_to_thai(text_to_translate)
print(translated_text)