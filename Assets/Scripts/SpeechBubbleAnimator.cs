using System.Collections;
using UnityEngine;
using TMPro;

public class SpeechBubbleAnimator : MonoBehaviour
{
    [Header("Animation Settings")]
    public Vector3 growScale = new Vector3(0.003f, 0.003f, 0.003f);
    public float growDuration = 1f;
    public float shakeDuration = 1f;
    public float shakeIntensity = 0.005f;
    public float shrinkDuration = 1f;
    public TextMeshProUGUI textDialoge;
    private Vector3 originalScale;
    private Vector3 originalPosition;

    private int chunkSize=60;
    static float interval = 5f;
    WaitForSeconds textInterval = new WaitForSeconds(interval);

    private void Awake()
    {
        originalScale = transform.localScale;
        originalPosition = transform.localPosition;
        textDialoge.text="";
    }

    public void AnimateIn(string text)
    {
        StopAllCoroutines();
        StartCoroutine(GrowAndShake(text,false));
    }
    public void AnimateInShake(string text)
    {
        StopAllCoroutines();
        StartCoroutine(GrowAndShake(text,true));
    }

    public void AnimateOut()
    {
        StopAllCoroutines();
        StartCoroutine(Shrink());
    }
    private IEnumerator GrowAndShake(string textToShow,bool allowShake=false)
    {
        float timer = 0f;
        while (timer < growDuration)
        {
            float progress = timer / growDuration;
            transform.localScale = Vector3.Lerp(originalScale, growScale, progress);
            timer += Time.deltaTime;
            yield return null;
        }
        transform.localScale = growScale;

        for (int offset = 0; offset < textToShow.Length; offset += chunkSize)
        {
            int length = Mathf.Min(chunkSize, textToShow.Length - offset);
            string chunk = textToShow.Substring(offset, length);
            textDialoge.text = chunk;
            
            textDialoge.maxVisibleCharacters = chunk.Length;
            yield return textInterval;
            

        }

        if(!allowShake)yield break;
        float shakeTimer = 0f;
        Vector3 shakeStartPosition = transform.localPosition;
        
        while (shakeTimer < shakeDuration)
        {
            transform.localPosition = shakeStartPosition + Random.insideUnitSphere * shakeIntensity;
            shakeTimer += Time.deltaTime;
            yield return null;
        }
        
        transform.localPosition = originalPosition;
    }

    private IEnumerator Shrink()
    {
        float timer = 0f;
        Vector3 startScale = transform.localScale;

        while (timer < shrinkDuration)
        {
            float progress = timer / shrinkDuration;
            transform.localScale = Vector3.Lerp(startScale, Vector3.zero, progress);
            timer += Time.deltaTime;
            yield return null;
        }
        
        transform.localScale = Vector3.zero;
    }
}
