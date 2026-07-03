import os

class GeminiApiKeys:
    """Provides a list of Gemini API keys."""

    def __init__(self, api_keys: list[str] = None):
        if api_keys is None:
            # Load keys from environment variables or a config file

            self.api_keys = [
                # ⚠️  UPDATE THESE WITH YOUR VALID GEMINI API KEYS ⚠️
                # Get fresh keys from: https://aistudio.google.com/app/apikey
                
                
                "AIzaSyBgN-4pR9gp5slq9r4jW7FVkXXxPXCTcIg",
                "AIzaSyDhHLF5ZLESWbF_AKThs1CN2cyP6Jb5OpE",

                # naurf keys
                "AIzaSyB-vNmCcR9mie0dBT1fj9CK5mHm4Na4I10", #SECOND PROJECT
                "AIzaSyBctcO8Nsi8nJR36uSY0c89kK6FHMPxb7Y", #gen ai
                "AIzaSyCl5fiuDVPiKHbggghpVaSaYiitumILSk0", # THIRD KEY

                # awun
                "AIzaSyARNB0cHP279LIGi5ab7Nbq4-oc8nx3wjE", #BALANCER
                "AIzaSyA1y0QXzbiYfJJiEbWl3wm1GNZZDieqcDc", #SECOND
                "AIzaSyDqNAm_j-knObCNaWBRhF9ENi-ol1eg5_Y", #THIRD

                #Undefined
                "AIzaSyDQU_VYReCA8NeeOewPdtMkNi-XEdW5pVQ", #TROUBLE
                "AIzaSyBK6iSDTOABQov-SueFM6EXpFDVNMjsI9U", #SECOND
                "AIzaSyDd9WgL5xggI4W2uifzgdzKqqQQccxdfns", #THIRD
                 ]
        else:
            self.api_keys = api_keys

    def get_keys(self) -> list[str]:
        """Returns the list of API keys."""
        return self.api_keys
