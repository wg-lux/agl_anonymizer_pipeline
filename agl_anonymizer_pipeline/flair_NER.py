from flair.data import Sentence
from flair.models import SequenceTagger

def NER_German(text):
    # Check if input is a string
    if not isinstance(text, str):
        print(f"Expected a string, but got {type(text)}")
        return None

    try:
        tagger = SequenceTagger.load("flair/ner-german-large")

        # Convert string to Sentence object
        sentence = Sentence(text)

        # Predict NER tags
        tagger.predict(sentence)

        # Print the sentence (optional)
        print(sentence)

        # Print predicted NER spans

        # Get NER spans
        entities = sentence.get_spans('ner')

        # Check if any entity is found
        if entities:
            print('The following NER tags are found:')
            for entity in entities:
                print(entity)
                
            # Flag to check if 'PER' tag is found
            per_found = False

            # Check each entity for 'PER' tag
            for entity in entities:
                if entity.tag == 'PER':
                    per_found = True
                    break

            # Implement if/else logic based on 'PER' tag presence
            if per_found:
                print("A person tag ('PER') was found in the text. Replacing...")
            else:
                print("No person tag ('PER') was found in the text.")
            return entities
        else:
            print("No entities found")
            return None
    except Exception as e:
        print("Error:", e)
        return None